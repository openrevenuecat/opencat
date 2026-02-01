import Foundation
import Network

// MARK: - NetworkMonitor

/// Monitors network connectivity status using NWPathMonitor
@MainActor
public final class NetworkMonitor: ObservableObject {

    // MARK: - Singleton

    public static let shared = NetworkMonitor()

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false

    // MARK: - Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.rushday.networkmonitor", qos: .utility)
    private var isMonitoring = false

    /// Callbacks for network state changes
    private var onConnectedCallbacks: [() -> Void] = []
    private var onDisconnectedCallbacks: [() -> Void] = []

    // MARK: - Types

    public enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
    }

    // MARK: - Init

    private init() {
        self.monitor = NWPathMonitor()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }

        monitor.start(queue: queue)
    }

    /// Stop monitoring network changes
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
    }

    /// Register a callback to be called when network becomes available
    public func onConnected(_ callback: @escaping () -> Void) {
        onConnectedCallbacks.append(callback)
    }

    /// Register a callback to be called when network becomes unavailable
    public func onDisconnected(_ callback: @escaping () -> Void) {
        onDisconnectedCallbacks.append(callback)
    }

    /// Wait for network to become available (with timeout)
    public func waitForConnection(timeout: TimeInterval = 30) async -> Bool {
        if isConnected { return true }

        return await withCheckedContinuation { continuation in
            var resumed = false
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !resumed {
                    resumed = true
                    continuation.resume(returning: false)
                }
            }

            onConnected {
                if !resumed {
                    resumed = true
                    timeoutTask.cancel()
                    continuation.resume(returning: true)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        connectionType = getConnectionType(from: path)

        // Trigger callbacks on state change
        if isConnected && !wasConnected {
            onConnectedCallbacks.forEach { $0() }
        } else if !isConnected && wasConnected {
            onDisconnectedCallbacks.forEach { $0() }
        }
    }

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}
