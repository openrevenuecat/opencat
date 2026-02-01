import Foundation
import Network

// MARK: - Local Network Discovery Service

/// Service to discover and manage local development server IPs
/// Only used in DEBUG mode for connecting to local gRPC backend
@MainActor
public final class LocalNetworkDiscoveryService: ObservableObject {

    // MARK: - Singleton

    public static let shared = LocalNetworkDiscoveryService()

    // MARK: - Published Properties

    @Published public private(set) var activeHost: String?
    @Published public private(set) var isDiscovering = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var knownHosts: [String] = []

    // MARK: - Constants

    private let defaultHosts = [
        "192.168.1.6",
        "192.168.68.55",
        "192.168.88.88",
        "192.168.1.3",
        "172.20.10.2"
    ]

    private let grpcPort = 50051
    private let connectionTimeout: TimeInterval = 2.0

    // MARK: - Storage Keys

    private let knownHostsKey = "debug_local_network_known_hosts"
    private let activeHostKey = "debug_local_network_active_host"

    // MARK: - Init

    private init() {
        loadKnownHosts()
        loadActiveHost()
    }

    // MARK: - Public Methods

    /// Discover a working local server from known hosts
    /// Checks all hosts in parallel and returns the first one that responds
    public func discoverLocalServer() async -> String? {
        // Skip discovery if AI generation is in progress (TCP probes interfere with gRPC stream on same port)
        if await MainActor.run(body: { AIEventPlannerViewModel.shared.isGenerating }) {
            #if DEBUG
            print("[LocalNetwork] Skipping discovery - AI generation in progress")
            #endif
            return activeHost
        }

        isDiscovering = true
        lastError = nil

        defer { isDiscovering = false }

        let hostsToCheck = knownHosts.isEmpty ? defaultHosts : knownHosts

        #if DEBUG
        print("[LocalNetwork] Starting discovery for \(hostsToCheck.count) hosts: \(hostsToCheck)")
        #endif

        // Check all hosts in parallel
        let result: String? = await withTaskGroup(of: (String, Bool).self) { group in
            for host in hostsToCheck {
                group.addTask {
                    let isReachable = await self.checkHost(host)
                    return (host, isReachable)
                }
            }

            // Return first working host
            for await (host, isReachable) in group {
                if isReachable {
                    #if DEBUG
                    print("[LocalNetwork] Found working host: \(host)")
                    #endif
                    // Cancel remaining tasks
                    group.cancelAll()
                    return host
                }
            }

            return nil
        }

        if let workingHost = result {
            activeHost = workingHost
            saveActiveHost(workingHost)
            return workingHost
        }

        // Try to find server on local network
        if let discovered = await scanLocalNetwork() {
            activeHost = discovered
            addKnownHost(discovered)
            saveActiveHost(discovered)
            return discovered
        }

        lastError = "No local server found. Please check if backend is running."
        #if DEBUG
        print("[LocalNetwork] No working host found")
        #endif

        return nil
    }

    /// Check if the currently active host is still reachable
    public func verifyActiveHost() async -> Bool {
        guard let host = activeHost else { return false }
        return await checkHost(host)
    }

    /// Add a new known host
    public func addKnownHost(_ host: String) {
        guard !knownHosts.contains(host) else { return }
        knownHosts.append(host)
        saveKnownHosts()

        #if DEBUG
        print("[LocalNetwork] Added known host: \(host)")
        #endif
    }

    /// Remove a known host
    public func removeKnownHost(_ host: String) {
        knownHosts.removeAll { $0 == host }
        saveKnownHosts()

        if activeHost == host {
            activeHost = nil
            UserDefaults.standard.removeObject(forKey: activeHostKey)
        }

        #if DEBUG
        print("[LocalNetwork] Removed known host: \(host)")
        #endif
    }

    /// Set a specific host as active (manual override)
    public func setActiveHost(_ host: String) async -> Bool {
        #if DEBUG
        print("[LocalNetwork] Manually setting host: \(host)")
        #endif

        if await checkHost(host) {
            activeHost = host
            addKnownHost(host)
            saveActiveHost(host)
            lastError = nil
            return true
        } else {
            lastError = "Could not connect to \(host):\(grpcPort)"
            return false
        }
    }

    /// Reset to default hosts
    public func resetToDefaults() {
        knownHosts = defaultHosts
        activeHost = nil
        lastError = nil
        saveKnownHosts()
        UserDefaults.standard.removeObject(forKey: activeHostKey)

        #if DEBUG
        print("[LocalNetwork] Reset to defaults")
        #endif
    }

    /// Get the current device's local IP address
    public func getDeviceIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Check for IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Filter for WiFi interface (en0)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    // MARK: - Private Methods

    /// Check if a host is reachable on the gRPC port
    private func checkHost(_ host: String) async -> Bool {
        #if DEBUG
        print("[LocalNetwork] Checking host: \(host):\(grpcPort)")
        #endif

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(grpcPort)),
                using: .tcp
            )

            var hasResumed = false
            let resumeOnce: (Bool) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + connectionTimeout) {
                resumeOnce(false)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    #if DEBUG
                    print("[LocalNetwork] Host \(host) is reachable")
                    #endif
                    resumeOnce(true)
                case .failed, .cancelled:
                    #if DEBUG
                    print("[LocalNetwork] Host \(host) failed")
                    #endif
                    resumeOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Scan local network for gRPC servers (basic subnet scan)
    private func scanLocalNetwork() async -> String? {
        guard let deviceIP = getDeviceIPAddress() else {
            #if DEBUG
            print("[LocalNetwork] Could not get device IP for network scan")
            #endif
            return nil
        }

        // Extract subnet (e.g., "192.168.1" from "192.168.1.100")
        let components = deviceIP.split(separator: ".")
        guard components.count == 4 else { return nil }

        let subnet = components.dropLast().joined(separator: ".")

        #if DEBUG
        print("[LocalNetwork] Scanning subnet: \(subnet).x for gRPC servers")
        #endif

        // Common local server IPs to check (don't scan all 255, just common ones)
        let commonLastOctets = [1, 2, 3, 4, 5, 6, 10, 100, 88, 99]
        let candidateHosts = commonLastOctets.map { "\(subnet).\($0)" }

        // Filter out hosts we already checked
        let newHosts = candidateHosts.filter { !knownHosts.contains($0) && !defaultHosts.contains($0) }

        guard !newHosts.isEmpty else { return nil }

        // Check new hosts in parallel with a limit
        return await withTaskGroup(of: (String, Bool).self) { group in
            for host in newHosts.prefix(10) {
                group.addTask {
                    let isReachable = await self.checkHost(host)
                    return (host, isReachable)
                }
            }

            for await (host, isReachable) in group {
                if isReachable {
                    #if DEBUG
                    print("[LocalNetwork] Discovered server at: \(host)")
                    #endif
                    group.cancelAll()
                    return host
                }
            }

            return nil
        }
    }

    // MARK: - Persistence

    private func loadKnownHosts() {
        if let hosts = UserDefaults.standard.stringArray(forKey: knownHostsKey), !hosts.isEmpty {
            // Merge saved hosts with default hosts (defaults first, then saved hosts that aren't defaults)
            var merged = defaultHosts
            for host in hosts where !merged.contains(host) {
                merged.append(host)
            }
            knownHosts = merged
        } else {
            knownHosts = defaultHosts
        }
    }

    private func saveKnownHosts() {
        UserDefaults.standard.set(knownHosts, forKey: knownHostsKey)
    }

    private func loadActiveHost() {
        activeHost = UserDefaults.standard.string(forKey: activeHostKey)
    }

    private func saveActiveHost(_ host: String) {
        UserDefaults.standard.set(host, forKey: activeHostKey)
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
extension LocalNetworkDiscoveryService {
    /// Get a summary of current state for debugging
    public var debugSummary: String {
        """
        Active Host: \(activeHost ?? "None")
        Known Hosts: \(knownHosts.joined(separator: ", "))
        Device IP: \(getDeviceIPAddress() ?? "Unknown")
        Is Discovering: \(isDiscovering)
        Last Error: \(lastError ?? "None")
        """
    }
}
#endif
