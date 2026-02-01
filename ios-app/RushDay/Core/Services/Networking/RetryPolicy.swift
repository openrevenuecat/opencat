import Foundation
import GRPC

// MARK: - RetryPolicy

/// Configuration for retry behavior
public struct RetryPolicy: Sendable {

    // MARK: - Properties

    /// Maximum number of retry attempts (not including the initial attempt)
    public let maxRetries: Int

    /// Base delay between retries (will be multiplied by backoff factor)
    public let baseDelay: TimeInterval

    /// Maximum delay between retries
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let backoffMultiplier: Double

    /// Whether to add jitter to delays to prevent thundering herd
    public let useJitter: Bool

    /// Timeout for each individual attempt
    public let attemptTimeout: TimeInterval?

    /// Whether to wait for network connectivity before retrying
    public let waitForConnectivity: Bool

    // MARK: - Presets

    /// Default retry policy: 3 retries, exponential backoff starting at 1s
    public static let `default` = RetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        useJitter: true,
        attemptTimeout: 30.0,
        waitForConnectivity: true
    )

    /// Aggressive retry for critical operations: 5 retries, longer delays
    public static let aggressive = RetryPolicy(
        maxRetries: 5,
        baseDelay: 2.0,
        maxDelay: 60.0,
        backoffMultiplier: 2.0,
        useJitter: true,
        attemptTimeout: 45.0,
        waitForConnectivity: true
    )

    /// Quick retry for fast operations: 2 retries, short delays
    public static let quick = RetryPolicy(
        maxRetries: 2,
        baseDelay: 0.5,
        maxDelay: 5.0,
        backoffMultiplier: 2.0,
        useJitter: true,
        attemptTimeout: 15.0,
        waitForConnectivity: false
    )

    /// No retry - fail immediately
    public static let none = RetryPolicy(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0,
        useJitter: false,
        attemptTimeout: nil,
        waitForConnectivity: false
    )

    // MARK: - Init

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        useJitter: Bool = true,
        attemptTimeout: TimeInterval? = 30.0,
        waitForConnectivity: Bool = true
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.useJitter = useJitter
        self.attemptTimeout = attemptTimeout
        self.waitForConnectivity = waitForConnectivity
    }

    // MARK: - Delay Calculation

    /// Calculate delay for a given attempt number (0-indexed)
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt))
        let clampedDelay = min(exponentialDelay, maxDelay)

        if useJitter {
            // Add random jitter between 0-25% of the delay
            let jitter = clampedDelay * Double.random(in: 0...0.25)
            return clampedDelay + jitter
        }

        return clampedDelay
    }
}

// MARK: - RetryableError

/// Classification of errors for retry decisions
public enum RetryableError {
    /// Error is transient and should be retried
    case transient
    /// Error is permanent and should not be retried
    case permanent
    /// Authentication error - attempt token refresh then retry once
    case authenticationRequired

    /// Classify a gRPC status code
    public static func classify(grpcStatus: GRPCStatus.Code) -> RetryableError {
        // Use raw value comparison for more robust handling
        switch grpcStatus.rawValue {
        // Transient errors - safe to retry
        case 14, // UNAVAILABLE - Server temporarily unavailable
             4,  // DEADLINE_EXCEEDED - Request timed out
             8,  // RESOURCE_EXHAUSTED - Rate limited or out of resources
             10, // ABORTED - Operation was aborted
             13, // INTERNAL - Internal server error (may be transient)
             2:  // UNKNOWN - Unknown error (may be transient)
            return .transient

        // Authentication errors - try token refresh
        case 16: // UNAUTHENTICATED
            return .authenticationRequired

        // Permanent errors - do not retry
        case 0,  // OK - Success (shouldn't happen in error path)
             1,  // CANCELLED - Explicitly cancelled
             3,  // INVALID_ARGUMENT - Bad request data
             5,  // NOT_FOUND - Resource doesn't exist
             6,  // ALREADY_EXISTS - Resource already exists
             7,  // PERMISSION_DENIED - Authorization failed
             9,  // FAILED_PRECONDITION - State precondition failed
             11, // OUT_OF_RANGE - Value out of range
             12, // UNIMPLEMENTED - Method not implemented
             15: // DATA_LOSS - Unrecoverable data loss
            return .permanent

        default:
            return .transient // Be conservative with unknown errors
        }
    }

    /// Classify a general error
    public static func classify(error: Error) -> RetryableError {
        // Check for gRPC-specific errors
        if let grpcError = error as? GRPCStatus {
            return classify(grpcStatus: grpcError.code)
        }

        // Check for URL/network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return .transient
            default:
                return .permanent
            }
        }

        // Check for our custom GRPCError
        if let grpcError = error as? GRPCError {
            switch grpcError {
            case .notConnected:
                return .transient
            case .invalidResponse:
                return .permanent
            case .serverError:
                return .transient
            }
        }

        // Check error description for hints
        let description = error.localizedDescription.lowercased()
        if description.contains("unavailable") ||
           description.contains("timeout") ||
           description.contains("connection") ||
           description.contains("network") {
            return .transient
        }

        // Default to transient to be conservative
        return .transient
    }
}

// MARK: - RetryResult

/// Result of a retry operation
public enum RetryResult<T> {
    case success(T)
    case failure(Error, attempts: Int)
    case cancelled
}
