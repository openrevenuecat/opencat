import SwiftUI

// MARK: - Debug View (Dev Mode Only)
struct DebugView: View {
    @StateObject private var networkLogger = NetworkLogger.shared
    @State private var selectedTab = 0
    @State private var selectedLog: NetworkLogEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Debug Section", selection: $selectedTab) {
                    Text("Environment").tag(0)
                    Text("Network").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Content
                if selectedTab == 0 {
                    EnvironmentInfoView()
                } else {
                    NetworkLogsView(
                        logs: networkLogger.logs,
                        isEnabled: $networkLogger.isEnabled,
                        onClear: { networkLogger.clearLogs() },
                        onSelect: { log in selectedLog = log }
                    )
                }
            }
            .background(Color.rdBackground)
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedLog) { log in
                NetworkLogDetailView(log: log)
            }
        }
    }
}

// MARK: - Environment Info View
struct EnvironmentInfoView: View {
    private let config = AppConfig.shared
    @State private var isMigrating = false
    @State private var migrationResult: MigrationResult?
    @State private var showMigrationAlert = false
    @State private var showLiquidGlassTest = false
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Subscription override state
    @AppStorage("debug_subscription_override_enabled") private var subscriptionOverrideEnabled = false
    @AppStorage("debug_subscription_override_value") private var subscriptionOverrideValue = true

    enum MigrationResult {
        case success(eventsMigrated: Int, alreadyMigrated: Bool)
        case error(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Subscription Debug Section
                DebugSection(title: "Subscription") {
                    // Current status
                    HStack {
                        Image(systemName: appState.isSubscribed ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundColor(appState.isSubscribed ? .rdSuccess : .rdTextTertiary)

                        Text("Current Status")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.rdTextPrimary)

                        Spacer()

                        Text(appState.isSubscribed ? "Premium" : "Free")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(appState.isSubscribed ? .rdSuccess : .rdTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .background(Color.rdDivider)

                    // Override toggle
                    Toggle(isOn: $subscriptionOverrideEnabled) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.rdPrimary)

                            Text("Override Subscription")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)
                        }
                    }
                    .tint(.rdPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onChange(of: subscriptionOverrideEnabled) { _, newValue in
                        appState.setSubscriptionOverride(enabled: newValue, value: subscriptionOverrideValue)
                    }

                    if subscriptionOverrideEnabled {
                        Divider()
                            .background(Color.rdDivider)

                        // Override value toggle
                        Toggle(isOn: $subscriptionOverrideValue) {
                            HStack {
                                Image(systemName: subscriptionOverrideValue ? "crown.fill" : "crown")
                                    .foregroundColor(subscriptionOverrideValue ? .rdSuccess : .rdTextTertiary)

                                Text("Simulate Premium")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.rdTextPrimary)
                            }
                        }
                        .tint(.rdSuccess)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .onChange(of: subscriptionOverrideValue) { _, newValue in
                            appState.setSubscriptionOverride(enabled: subscriptionOverrideEnabled, value: newValue)
                        }
                    }
                }

                // Debug Actions
                DebugSection(title: "Debug Actions") {
                    Button(action: {
                        Task {
                            await migrateFromFirebase()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.rdPrimary)

                            Text("Migrate from Firebase")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            if isMigrating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.rdTextTertiary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .disabled(isMigrating)

                    Divider()
                        .background(Color.rdDivider)

                    Button(action: resetOnboarding) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.rdPrimary)

                            Text("Reset Onboarding")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .background(Color.rdDivider)

                    Button(action: { showLiquidGlassTest = true }) {
                        HStack {
                            Image(systemName: "cube.transparent")
                                .foregroundColor(.rdPrimary)

                            Text("Liquid Glass Lab")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .background(Color.rdDivider)

                    Button(action: resetRateUs) {
                        HStack {
                            Image(systemName: "star.slash")
                                .foregroundColor(.rdPrimary)

                            Text("Reset Rate Us")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .background(Color.rdDivider)

                    Button(action: clearImageCache) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.rdPrimary)

                            Text("Clear Image Cache")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .background(Color.rdDivider)

                    Button(action: clearEventCache) {
                        HStack {
                            Image(systemName: "tray.full")
                                .foregroundColor(.rdWarning)

                            Text("Clear Cache & Reload")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // Environment Section
                DebugSection(title: "Environment") {
                    DebugInfoRow(label: "Mode", value: config.environment.displayName)
                    DebugInfoRow(label: "Is Dev Mode", value: config.isDevMode ? "Yes" : "No")
                }

                // gRPC Configuration
                DebugSection(title: "gRPC Configuration") {
                    DebugInfoRow(label: "Host", value: config.grpcHost)
                    DebugInfoRow(label: "Port", value: "\(config.grpcPort)")
                    DebugInfoRow(label: "TLS", value: config.grpcUseTLS ? "Enabled" : "Disabled")
                }

                // Local Network Section (Debug only)
                if config.isDevMode {
                    LocalNetworkSection()
                }

                // Firebase Configuration
                DebugSection(title: "Firebase") {
                    DebugInfoRow(label: "Project ID", value: config.firebaseProjectId)
                }

                // Storage URLs
                DebugSection(title: "Storage") {
                    DebugInfoRow(label: "Media URL", value: config.mediaSourceUrl, isMultiline: true)
                    DebugInfoRow(label: "Bucket", value: config.bucketName)
                }

                // Web App URLs
                DebugSection(title: "Web URLs") {
                    DebugInfoRow(label: "Web App", value: config.webAppUrl)
                    DebugInfoRow(label: "Notifications", value: config.notificationServiceUrl)
                }

                // App Info
                DebugSection(title: "App Info") {
                    DebugInfoRow(label: "Version", value: config.appVersion)
                    DebugInfoRow(label: "Build", value: config.buildNumber)
                    DebugInfoRow(label: "Full Version", value: config.fullVersion)
                    DebugInfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                }

                // Device Info
                DebugSection(title: "Device") {
                    DebugInfoRow(label: "OS", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    DebugInfoRow(label: "Model", value: UIDevice.current.model)
                    DebugInfoRow(label: "Name", value: UIDevice.current.name)
                }
            }
            .padding(16)
        }
        .alert("Migration Result", isPresented: $showMigrationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = migrationResult {
                switch result {
                case .success(let eventsMigrated, let alreadyMigrated):
                    if alreadyMigrated {
                        Text("Already migrated. No new data to migrate.")
                    } else {
                        Text("Successfully migrated \(eventsMigrated) events.")
                    }
                case .error(let message):
                    Text("Error: \(message)")
                }
            }
        }
        .fullScreenCover(isPresented: $showLiquidGlassTest) {
            LiquidGlassTestView()
        }
    }

    // MARK: - Migration

    private func migrateFromFirebase() async {
        isMigrating = true
        defer { isMigrating = false }

        do {
            let response = try await GRPCClientService.shared.migrateUserData(appVersion: config.fullVersion)
            migrationResult = .success(
                eventsMigrated: Int(response.stats.eventsMigrated),
                alreadyMigrated: response.alreadyMigrated
            )
        } catch {
            migrationResult = .error(error.localizedDescription)
        }

        showMigrationAlert = true
    }

    // MARK: - Reset Onboarding

    private func resetOnboarding() {
        // Reset onboarding state in AppState
        appState.resetOnboarding()
        // Sign out to trigger auth state change
        appState.signOut()
    }

    private func resetRateUs() {
        RateUsService.shared.resetForTesting()
    }

    private func clearImageCache() {
        ImageCache.shared.clearMemoryCache()
        ImageCache.shared.clearDiskCache()
    }

    private func clearEventCache() {
        // AppState handles dismissing the sheet and triggering reload
        appState.clearAllEventCacheAndReload()
    }
}

// MARK: - Network Logs View
struct NetworkLogsView: View {
    let logs: [NetworkLogEntry]
    @Binding var isEnabled: Bool
    let onClear: () -> Void
    let onSelect: (NetworkLogEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack {
                Toggle("Logging", isOn: $isEnabled)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Button(action: onClear) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rdWarning)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.rdBackgroundSecondary)

            // Logs List
            if logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.rdTextTertiary)

                    Text("No network requests logged")
                        .font(.system(size: 15))
                        .foregroundColor(.rdTextSecondary)

                    Text("Make some API calls to see them here")
                        .font(.system(size: 13))
                        .foregroundColor(.rdTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(logs) { log in
                    NetworkLogRow(log: log)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.rdBackgroundSecondary)
                        .onTapGesture {
                            onSelect(log)
                        }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Network Log Row
struct NetworkLogRow: View {
    let log: NetworkLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Method + Endpoint
            HStack(spacing: 8) {
                Text(log.method)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(methodColor)
                    .cornerRadius(4)

                Text(log.endpoint)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.rdTextPrimary)
                    .lineLimit(1)

                Spacer()
            }

            // Host + Status
            HStack {
                Text(log.host)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.rdTextTertiary)
                    .lineLimit(1)

                Spacer()

                if log.error != nil {
                    Text("Error")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rdWarning)
                } else if let status = log.responseStatus {
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rdSuccess)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                if let duration = log.formattedDuration {
                    Text(duration)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rdTextTertiary)
                }
            }

            // Timestamp
            Text(log.formattedTimestamp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.rdTextTertiary)
        }
        .padding(.vertical, 4)
    }

    private var methodColor: Color {
        switch log.method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
}

// MARK: - Network Log Detail View
struct NetworkLogDetailView: View {
    let log: NetworkLogEntry
    @Environment(\.dismiss) private var dismiss
    @State private var copiedField: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Overview
                    DebugSection(title: "Overview") {
                        DebugInfoRow(label: "Method", value: log.method)
                        DebugInfoRow(label: "Endpoint", value: log.endpoint, isMultiline: true)
                        DebugInfoRow(label: "Host", value: log.host)
                        DebugInfoRow(label: "Timestamp", value: log.formattedTimestamp)
                        if let duration = log.formattedDuration {
                            DebugInfoRow(label: "Duration", value: duration)
                        }
                    }

                    // Status
                    if let error = log.error {
                        DebugSection(title: "Error") {
                            Text(error)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.rdWarning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    } else if let status = log.responseStatus {
                        DebugSection(title: "Response Status") {
                            Text(status)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.rdSuccess)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }

                    // Headers
                    if !log.requestHeaders.isEmpty {
                        DebugSection(title: "Request Headers") {
                            ForEach(Array(log.requestHeaders.keys.sorted()), id: \.self) { key in
                                if let value = log.requestHeaders[key] {
                                    DebugInfoRow(label: key, value: value, isMultiline: true)
                                }
                            }
                        }
                    }

                    // Request Body
                    if let requestBody = log.requestBody, !requestBody.isEmpty {
                        JSONBodySection(
                            title: "Request Body",
                            json: requestBody,
                            isCopied: copiedField == "request",
                            onCopy: {
                                UIPasteboard.general.string = requestBody
                                copiedField = "request"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedField == "request" { copiedField = nil }
                                }
                            }
                        )
                    }

                    // Response Body
                    if let responseBody = log.responseBody, !responseBody.isEmpty {
                        JSONBodySection(
                            title: "Response Body",
                            json: responseBody,
                            isCopied: copiedField == "response",
                            onCopy: {
                                UIPasteboard.general.string = responseBody
                                copiedField = "response"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedField == "response" { copiedField = nil }
                                }
                            }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.rdBackground)
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - JSON Body Section
struct JSONBodySection: View {
    let title: String
    let json: String
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with copy button
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rdTextSecondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isCopied ? .rdSuccess : .rdPrimary)
                }
            }

            // JSON content
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(prettyPrintJSON(json))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.rdTextPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
            .padding(12)
            .background(Color.rdBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Pretty print JSON string with indentation
    private func prettyPrintJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
}

// MARK: - Debug Section
struct DebugSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.rdTextSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color.rdBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Debug Info Row
struct DebugInfoRow: View {
    let label: String
    let value: String
    var isMultiline: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if isMultiline {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.rdTextSecondary)

                    Text(value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.rdTextPrimary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.rdTextSecondary)

                    Spacer()

                    Text(value)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.rdTextPrimary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Local Network Section

struct LocalNetworkSection: View {
    @StateObject private var networkService = LocalNetworkDiscoveryService.shared
    @EnvironmentObject var appState: AppState
    @State private var newHostIP = ""
    @State private var showAddHost = false
    @State private var isTestingHost = false
    @State private var testResult: String?

    var body: some View {
        DebugSection(title: "Local Network (Dev)") {
            // Active Host
            HStack {
                Image(systemName: networkService.activeHost != nil ? "wifi" : "wifi.slash")
                    .foregroundColor(networkService.activeHost != nil ? .rdSuccess : .rdWarning)

                Text("Active Host")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rdTextPrimary)

                Spacer()

                if networkService.isDiscovering {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(networkService.activeHost ?? "None")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(networkService.activeHost != nil ? .rdSuccess : .rdTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.rdDivider)

            // Device IP
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.rdPrimary)

                Text("Device IP")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rdTextPrimary)

                Spacer()

                Text(networkService.getDeviceIPAddress() ?? "Unknown")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.rdTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.rdDivider)

            // Discover Button
            Button(action: {
                Task {
                    if let _ = await networkService.discoverLocalServer() {
                        // Reconnect gRPC with the newly discovered host
                        appState.reconnectGRPC()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass.circle")
                        .foregroundColor(.rdPrimary)

                    Text("Auto-Discover Server")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.rdTextPrimary)

                    Spacer()

                    if networkService.isDiscovering {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.rdTextTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .disabled(networkService.isDiscovering)

            // Error message
            if let error = networkService.lastError {
                Divider().background(Color.rdDivider)
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.rdWarning)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.rdWarning)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider().background(Color.rdDivider)

            // Known Hosts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Known Hosts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.rdTextSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Button(action: { showAddHost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.rdPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ForEach(networkService.knownHosts, id: \.self) { host in
                    HStack {
                        Image(systemName: host == networkService.activeHost ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(host == networkService.activeHost ? .rdSuccess : .rdTextTertiary)
                            .font(.system(size: 14))

                        Text(host)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.rdTextPrimary)

                        Spacer()

                        // Test this host
                        Button(action: {
                            Task {
                                isTestingHost = true
                                let success = await networkService.setActiveHost(host)
                                if success {
                                    testResult = "Connected to \(host)"
                                    // Reconnect gRPC with the new host
                                    appState.reconnectGRPC()
                                } else {
                                    testResult = "Failed to connect"
                                }
                                isTestingHost = false
                                // Clear result after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    testResult = nil
                                }
                            }
                        }) {
                            Text("Use")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rdPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.rdPrimary.opacity(0.1))
                                .cornerRadius(6)
                        }

                        // Delete button
                        Button(action: {
                            networkService.removeKnownHost(host)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.rdTextTertiary)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                if let result = testResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundColor(result.contains("Connected") ? .rdSuccess : .rdWarning)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 12)

            Divider().background(Color.rdDivider)

            // Reset to Defaults
            Button(action: {
                networkService.resetToDefaults()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.rdWarning)

                    Text("Reset to Defaults")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.rdWarning)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .alert("Add Host", isPresented: $showAddHost) {
            TextField("IP Address (e.g., 192.168.1.100)", text: $newHostIP)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {
                newHostIP = ""
            }
            Button("Add") {
                if !newHostIP.isEmpty {
                    networkService.addKnownHost(newHostIP)
                    newHostIP = ""
                }
            }
        } message: {
            Text("Enter the IP address of your local gRPC server")
        }
    }
}

// MARK: - Preview
#Preview {
    DebugView()
}
