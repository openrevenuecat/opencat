import Foundation
import GRPC

// MARK: - RetryExecutor

/// Executes operations with automatic retry logic
public actor RetryExecutor {

    // MARK: - Singleton

    public static let shared = RetryExecutor()

    // MARK: - Properties

    /// Token refresh handler - set this to enable automatic token refresh on auth errors
    private var tokenRefreshHandler: (() async throws -> String)?

    /// Callback when retry starts
    private var onRetryStart: ((Int, TimeInterval) -> Void)?

    /// Callback when operation succeeds after retry
    private var onRetrySuccess: ((Int) -> Void)?

    /// Callback when all retries exhausted
    private var onRetryExhausted: ((Error, Int) -> Void)?

    // MARK: - Init

    private init() {}

    // MARK: - Configuration

    /// Set the token refresh handler for automatic retry on auth errors
    public func setTokenRefreshHandler(_ handler: @escaping () async throws -> String) {
        self.tokenRefreshHandler = handler
    }

    /// Set callback for when retry starts
    public func setOnRetryStart(_ callback: @escaping (Int, TimeInterval) -> Void) {
        self.onRetryStart = callback
    }

    /// Set callback for when operation succeeds after retry
    public func setOnRetrySuccess(_ callback: @escaping (Int) -> Void) {
        self.onRetrySuccess = callback
    }

    /// Set callback for when all retries exhausted
    public func setOnRetryExhausted(_ callback: @escaping (Error, Int) -> Void) {
        self.onRetryExhausted = callback
    }

    // MARK: - Execute with Retry

    /// Execute an async operation with automatic retry
    /// - Parameters:
    ///   - policy: The retry policy to use
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    public func execute<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= policy.maxRetries {
            // Wait for network connectivity if required and not first attempt
            if policy.waitForConnectivity && attempt > 0 {
                let isConnected = await MainActor.run { NetworkMonitor.shared.isConnected }
                if !isConnected {
                    let connected = await MainActor.run {
                        Task {
                            await NetworkMonitor.shared.waitForConnection(timeout: 30)
                        }
                    }
                    _ = await connected.value
                }
            }

            do {
                // Execute the operation
                if let timeout = policy.attemptTimeout {
                    return try await withTimeout(seconds: timeout) {
                        try await operation()
                    }
                } else {
                    return try await operation()
                }
            } catch {
                lastError = error
                let classification = RetryableError.classify(error: error)

                switch classification {
                case .permanent:
                    // Don't retry permanent errors
                    throw error

                case .authenticationRequired:
                    // Try to refresh token and retry once
                    if let refreshHandler = tokenRefreshHandler {
                        do {
                            let newToken = try await refreshHandler()
                            // The token is now refreshed, retry the operation
                            GRPCClientService.shared.setAuthToken(newToken)
                            // Continue to retry with the same attempt count
                            continue
                        } catch {
                            throw error
                        }
                    } else {
                        // No refresh handler, throw the error
                        throw error
                    }

                case .transient:
                    // Check if we have retries left
                    if attempt < policy.maxRetries {
                        let delay = policy.delay(forAttempt: attempt)

                        onRetryStart?(attempt + 1, delay)

                        // Wait before retrying
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                        attempt += 1
                        continue
                    } else {
                        onRetryExhausted?(error, attempt + 1)
                        throw error
                    }
                }
            }
        }

        // This should never be reached, but just in case
        throw lastError ?? GRPCError.invalidResponse
    }

    /// Execute with retry and return a result enum instead of throwing
    public func executeWithResult<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async -> RetryResult<T> {
        do {
            let result = try await execute(policy: policy, operation: operation)
            return .success(result)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failure(error, attempts: policy.maxRetries + 1)
        }
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - TimeoutError

public struct TimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Operation timed out"
    }
}

// MARK: - Retry Extension for GRPCClientService

extension GRPCClientService {

    /// Execute a gRPC call with automatic retry
    public func withRetry<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await RetryExecutor.shared.execute(policy: policy, operation: operation)
    }
}

// MARK: - Convenience Functions

/// Execute an async operation with default retry policy
public func withRetry<T>(
    policy: RetryPolicy = .default,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await RetryExecutor.shared.execute(policy: policy, operation: operation)
}

/// Execute an async operation with retry, returning result instead of throwing
public func withRetryResult<T>(
    policy: RetryPolicy = .default,
    operation: @escaping () async throws -> T
) async -> RetryResult<T> {
    await RetryExecutor.shared.executeWithResult(policy: policy, operation: operation)
}
