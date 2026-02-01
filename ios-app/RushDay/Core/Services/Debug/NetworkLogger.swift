import Foundation

// MARK: - Network Request Log Entry
public struct NetworkLogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let method: String
    public let endpoint: String
    public let host: String
    public let requestHeaders: [String: String]
    public let requestBody: String?
    public let responseStatus: String?
    public let responseBody: String?
    public let duration: TimeInterval?
    public let error: String?

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        return String(format: "%.2fms", duration * 1000)
    }

    public var isSuccess: Bool {
        error == nil && responseStatus != nil
    }
}

// MARK: - Network Logger (Singleton)
@MainActor
public final class NetworkLogger: ObservableObject {

    // MARK: - Singleton
    public static let shared = NetworkLogger()

    // MARK: - Published Properties
    @Published public private(set) var logs: [NetworkLogEntry] = []
    @Published public var isEnabled: Bool = true

    // MARK: - Configuration
    private let maxLogEntries = 100

    private init() {}

    // MARK: - Public Methods

    /// Log a gRPC request
    public func logRequest(
        method: String,
        endpoint: String,
        host: String,
        headers: [String: String] = [:],
        requestBody: String? = nil
    ) -> UUID {
        guard isEnabled else { return UUID() }

        let entry = NetworkLogEntry(
            timestamp: Date(),
            method: method,
            endpoint: endpoint,
            host: host,
            requestHeaders: headers,
            requestBody: requestBody,
            responseStatus: nil,
            responseBody: nil,
            duration: nil,
            error: nil
        )

        addLog(entry)
        return entry.id
    }

    /// Update a log entry with response
    public func logResponse(
        id: UUID,
        status: String,
        responseBody: String? = nil,
        duration: TimeInterval
    ) {
        guard isEnabled else { return }

        if let index = logs.firstIndex(where: { $0.id == id }) {
            let original = logs[index]
            let updated = NetworkLogEntry(
                timestamp: original.timestamp,
                method: original.method,
                endpoint: original.endpoint,
                host: original.host,
                requestHeaders: original.requestHeaders,
                requestBody: original.requestBody,
                responseStatus: status,
                responseBody: responseBody,
                duration: duration,
                error: nil
            )
            logs[index] = updated
        }
    }

    /// Update a log entry with error
    public func logError(
        id: UUID,
        error: String,
        duration: TimeInterval
    ) {
        guard isEnabled else { return }

        if let index = logs.firstIndex(where: { $0.id == id }) {
            let original = logs[index]
            let updated = NetworkLogEntry(
                timestamp: original.timestamp,
                method: original.method,
                endpoint: original.endpoint,
                host: original.host,
                requestHeaders: original.requestHeaders,
                requestBody: original.requestBody,
                responseStatus: nil,
                responseBody: nil,
                duration: duration,
                error: error
            )
            logs[index] = updated
        }
    }

    /// Log a complete request/response in one call
    public func log(
        method: String,
        endpoint: String,
        host: String,
        headers: [String: String] = [:],
        requestBody: String? = nil,
        responseStatus: String? = nil,
        responseBody: String? = nil,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        guard isEnabled else { return }

        let entry = NetworkLogEntry(
            timestamp: Date(),
            method: method,
            endpoint: endpoint,
            host: host,
            requestHeaders: headers,
            requestBody: requestBody,
            responseStatus: responseStatus,
            responseBody: responseBody,
            duration: duration,
            error: error
        )

        addLog(entry)
    }

    /// Clear all logs
    public func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Private Methods

    private func addLog(_ entry: NetworkLogEntry) {
        logs.insert(entry, at: 0)

        // Trim old entries
        if logs.count > maxLogEntries {
            logs = Array(logs.prefix(maxLogEntries))
        }
    }
}
