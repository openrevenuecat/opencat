import SwiftUI
import Combine
import FirebaseAuth

enum AuthState: Equatable {
    case unknown
    case authenticated(User)
    case unauthenticated
}

enum AppRoute: Hashable {
    case onboarding
    case auth
    case home
    case createEvent
    case eventDetails(eventId: String)
    case guests(eventId: String)
    case tasks(eventId: String)
    case agenda(eventId: String)
    case expenses(eventId: String)
    case settings
}

@MainActor
final class AppState: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var currentRoute: AppRoute = .auth
    @Published var isLoading: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isMigrating: Bool = false
    @Published var migrationError: String? = nil
    @Published private var _isSubscribed: Bool = false
    @Published var subscriptionExpirationDate: Date? = nil

    // MARK: - User Store (Single Source of Truth)
    /// The current authenticated user - this is the single source of truth for user data
    @Published var currentUser: User?

    // MARK: - Events Store (Single Source of Truth)
    @Published var events: [Event] = []
    @Published var draftEvents: [Event] = []
    @Published var isLoadingEvents: Bool = false

    // MARK: - Guests Store (Single Source of Truth)
    /// Guests indexed by eventId - this is the single source of truth for guest data
    @Published var guestsByEvent: [String: [Guest]] = [:]
    @Published var isLoadingGuests: Set<String> = []
    private var guestRefreshObserver: NSObjectProtocol?
    private var eventRefreshObserver: NSObjectProtocol?

    // MARK: - Expenses Store (Single Source of Truth)
    /// Expenses indexed by eventId - this is the single source of truth for expense data
    @Published var expensesByEvent: [String: [Expense]] = [:]
    /// Budget indexed by eventId
    @Published var budgetByEvent: [String: Double] = [:]
    @Published var isLoadingExpenses: Set<String> = []
    private var expenseRefreshObserver: NSObjectProtocol?

    // MARK: - Agenda Store (Single Source of Truth)
    /// Agenda items indexed by eventId - this is the single source of truth for agenda data
    @Published var agendaByEvent: [String: [AgendaItem]] = [:]
    @Published var isLoadingAgenda: Set<String> = []
    private var agendaRefreshObserver: NSObjectProtocol?

    // MARK: - Tasks Store (Single Source of Truth)
    /// Tasks indexed by eventId - this is the single source of truth for task data
    @Published var tasksByEvent: [String: [EventTask]] = [:]
    @Published var isLoadingTasks: Set<String> = []
    private var taskRefreshObserver: NSObjectProtocol?

    // Debug subscription override
    @Published private var subscriptionOverrideEnabled: Bool = false
    @Published private var subscriptionOverrideValue: Bool = true

    /// Returns true if user has premium access (either real or debug override)
    var isSubscribed: Bool {
        if subscriptionOverrideEnabled {
            return subscriptionOverrideValue
        }
        return _isSubscribed
    }
    // MARK: - AI Event Planner Flow

    /// Show the AI Event Planner wizard (for unauth users after onboarding)
    @Published var showAIEventPlanner: Bool = false

    /// Pending event data from AI planner (stored until user authenticates)
    @Published var pendingEventData: PendingEventData?

    /// Show AI Event Preview after authentication (when user has pending event from wizard)
    @Published var showAIEventPreviewAfterAuth: Bool = false

    /// True when user is signing in from within the AI planner flow (don't navigate away)
    @Published var isSigningInFromAIPlanner: Bool = false

    // MARK: - Deep Link State

    /// Pending deep link to handle after authentication
    @Published var pendingDeepLink: DeepLinkType?

    /// Show invitation accept dialog
    @Published var showInvitationDialog: Bool = false

    /// Show error alert (e.g., for invalid co-host invitation)
    @Published var showErrorAlert: Bool = false
    @Published var errorAlertMessage: String?

    // MARK: - Debug Screen State (DEBUG only)
    #if DEBUG
    /// Show paywall screen via deep link (rushday://debug/paywall)
    @Published var showDebugPaywall: Bool = false
    /// Show feature paywall sheet via deep link (rushday://debug/feature-paywall)
    @Published var showDebugFeaturePaywall: Bool = false
    /// Show onboarding via deep link (rushday://debug/onboarding)
    @Published var showDebugOnboarding: Bool = false
    /// Show AI event planner via deep link (rushday://debug/ai-planner)
    @Published var showDebugAIPlanner: Bool = false
    /// Show profile via deep link (rushday://debug/profile)
    @Published var showDebugProfile: Bool = false
    /// Show debug console via deep link (rushday://debug/console)
    @Published var showDebugConsole: Bool = false
    /// Show guests list for first event (rushday://debug/guests)
    @Published var showDebugGuests: Bool = false
    /// Show tasks list for first event (rushday://debug/tasks)
    @Published var showDebugTasks: Bool = false
    /// Show agenda for first event (rushday://debug/agenda)
    @Published var showDebugAgenda: Bool = false
    /// Show expenses for first event (rushday://debug/expenses)
    @Published var showDebugExpenses: Bool = false
    /// Show invitation preview for first event (rushday://debug/invitation-preview)
    @Published var showDebugInvitationPreview: Bool = false
    /// Show edit event for first event (rushday://debug/edit-event)
    @Published var showDebugEditEvent: Bool = false
    /// Show notification settings (rushday://debug/notification-settings)
    @Published var showDebugNotificationSettings: Bool = false
    /// Show edit task sheet directly (rushday://debug/edit-task)
    @Published var showDebugEditTask: Bool = false
    /// Show budget editor sheet directly (rushday://debug/budget-editor)
    @Published var showDebugBudgetEditor: Bool = false
    /// Show auth screen via deep link (rushday://debug/auth)
    @Published var showDebugAuth: Bool = false
    /// Debug event for screens that need an event
    @Published var debugEvent: Event?
    #endif

    /// The event for the current invitation dialog
    @Published var invitationEvent: Event?

    /// Pending co-host invitation secret (one-time token from invite link)
    @Published var pendingCoHostSecret: String?

    /// Event to navigate to programmatically (used after accepting co-host invitation)
    @Published var navigateToEvent: Event?

    private var cancellables = Set<AnyCancellable>()
    private var authStateHandle: Any?
    private var subscriptionTask: Task<Void, Never>?
    private let authService: AuthServiceProtocol
    private let migrationService: MigrationServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let revenueCatService: RevenueCatServiceProtocol

    init(
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        migrationService: MigrationServiceProtocol = DIContainer.shared.migrationService,
        notificationService: NotificationServiceProtocol = DIContainer.shared.notificationService,
        revenueCatService: RevenueCatServiceProtocol = DIContainer.shared.revenueCatService
    ) {
        self.authService = authService
        self.migrationService = migrationService
        self.notificationService = notificationService
        self.revenueCatService = revenueCatService
        loadOnboardingState()
        setupGRPCConnection()
        setupAuthStateListener()
        setupSubscriptionListener()
        setupUserProfileListener()
        setupGuestRefreshListener()
        setupEventRefreshListener()
        setupExpenseRefreshListener()
        setupAgendaRefreshListener()
        setupTaskRefreshListener()
    }

    // MARK: - gRPC Setup

    private func setupGRPCConnection() {
        let config = AppConfig.shared

        // Connect immediately with current host (from UserDefaults or default)
        // This ensures gRPC is ready before auth listener fires
        connectGRPC(config: config)

        #if DEBUG
        // In development mode, run discovery in background to update host for next time
        // If current host doesn't work, this will find a working one
        if config.isDevMode {
            Task {
                await runBackgroundDiscovery()
            }
        }
        #endif
    }

    /// Run discovery in background to find/verify working host (DEBUG only)
    /// If a different host is found, reconnects automatically
    private func runBackgroundDiscovery() async {
        // Skip discovery if AI generation is in progress (TCP probes interfere with gRPC stream)
        if AIEventPlannerViewModel.shared.isGenerating {
            #if DEBUG
            print("[gRPC] Skipping discovery - AI generation in progress")
            #endif
            return
        }

        let currentHost = AppConfig.shared.grpcHost

        // Try to discover a working host
        if let discoveredHost = await LocalNetworkDiscoveryService.shared.discoverLocalServer() {
            // If discovered host is different from what we connected with, reconnect
            if discoveredHost != currentHost {
                #if DEBUG
                print("[gRPC] Discovered different host: \(discoveredHost) (was: \(currentHost)). Reconnecting...")
                #endif
                await MainActor.run {
                    reconnectGRPC()
                }
            } else {
                #if DEBUG
                print("[gRPC] Verified host: \(discoveredHost)")
                #endif
            }
        } else {
            #if DEBUG
            print("[gRPC] No local server found. Go to Debug Console > Local Network to configure.")
            #endif
        }
    }

    /// Connect to gRPC server with given configuration
    private func connectGRPC(config: AppConfig) {
        do {
            let grpcConfig = GRPCClientService.Configuration(
                host: config.grpcHost,
                port: config.grpcPort,
                useTLS: config.grpcUseTLS
            )
            try GRPCClientService.shared.connect(configuration: grpcConfig)

            #if DEBUG
            print("[gRPC] Connected to \(config.grpcHost):\(config.grpcPort)")
            #endif

            // Setup retry system with token refresh handler
            setupRetrySystem()
        } catch {
            #if DEBUG
            print("[gRPC] Connection failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Reconnect gRPC to the current configured host (call after changing local network settings)
    /// - Parameter force: If true, reconnects even during active operations (default: false)
    func reconnectGRPC(force: Bool = false) {
        // Don't reconnect during AI plan generation (would kill the stream)
        if !force && AIEventPlannerViewModel.shared.isGenerating {
            #if DEBUG
            print("[gRPC] Skipping reconnect - AI generation in progress")
            #endif
            return
        }

        #if DEBUG
        print("[gRPC] Reconnecting...")
        #endif
        GRPCClientService.shared.disconnect()
        connectGRPC(config: AppConfig.shared)

        // Re-set auth token if authenticated
        Task {
            await refreshGRPCAuthToken()
        }
    }

    private func setupRetrySystem() {
        // Start network monitoring
        NetworkMonitor.shared.startMonitoring()

        // Configure token refresh handler for automatic retry on auth errors
        Task {
            await RetryExecutor.shared.setTokenRefreshHandler { [weak self] in
                guard let self = self else {
                    throw GRPCError.notConnected
                }
                return try await self.getRefreshedToken()
            }

            // Retry callbacks for analytics
            await RetryExecutor.shared.setOnRetryExhausted { error, attempts in
                AnalyticsService.shared.logEvent("retry_exhausted", parameters: [
                    "error": error.localizedDescription,
                    "attempts": attempts
                ])
            }
        }
    }

    /// Get a fresh Firebase ID token for retry
    nonisolated func getRefreshedToken() async throws -> String {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw GRPCError.notConnected
        }

        // Force refresh the token
        let token = try await firebaseUser.getIDToken(forcingRefresh: true)
        return token
    }

    /// Refreshes the Firebase ID token and sets it on the gRPC service
    private func refreshGRPCAuthToken() async {
        guard let firebaseUser = Auth.auth().currentUser else {
            GRPCClientService.shared.setAuthToken(nil)
            return
        }

        do {
            let token = try await firebaseUser.getIDToken()
            GRPCClientService.shared.setAuthToken(token)
        } catch {
            // Token refresh failed silently
        }
    }

    deinit {
        if let handle = authStateHandle {
            authService.removeAuthStateListener(handle)
        }
        subscriptionTask?.cancel()
    }

    // MARK: - User Profile Listener

    /// Listen for user profile updates from EditProfileView and other sources
    private func setupUserProfileListener() {
        NotificationCenter.default.addObserver(
            forName: .userProfileUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let updatedUser = notification.object as? User else { return }
            Task { @MainActor in
                self.currentUser = updatedUser
                // Also update authState to keep them in sync
                self.authState = .authenticated(updatedUser)
            }
        }
    }

    // MARK: - User Methods

    /// Load user data from backend
    func loadCurrentUser() async {
        guard case .authenticated = authState else {
            return
        }

        do {
            let grpcUser = try await GRPCClientService.shared.getCurrentUser()
            let user = User(from: grpcUser)
            currentUser = user
            authState = .authenticated(user)
        } catch {
            // Error handled silently
        }
    }

    // MARK: - Subscription Setup

    private func setupSubscriptionListener() {
        // Load debug override from UserDefaults
        loadSubscriptionOverride()

        subscriptionTask = Task {
            // Ensure RevenueCat is configured
            await revenueCatService.ensureConfigured()

            // Listen to subscription status updates
            for await status in revenueCatService.subscriptionStatusPublisher {
                await MainActor.run {
                    self._isSubscribed = status.isActive
                    self.subscriptionExpirationDate = status.expirationDate
                }
            }
        }
    }

    /// Manually refresh subscription status
    func refreshSubscriptionStatus() async {
        do {
            let status = try await revenueCatService.getSubscriptionStatus()
            _isSubscribed = status.isActive
            subscriptionExpirationDate = status.expirationDate
        } catch {
            // Subscription refresh failed silently
        }
    }

    /// Update subscription status after a purchase
    func updateSubscriptionStatus(_ isActive: Bool) {
        _isSubscribed = isActive
    }

    // MARK: - Debug Subscription Override

    /// Load subscription override settings from UserDefaults
    private func loadSubscriptionOverride() {
        subscriptionOverrideEnabled = UserDefaults.standard.bool(forKey: "debug_subscription_override_enabled")
        subscriptionOverrideValue = UserDefaults.standard.object(forKey: "debug_subscription_override_value") as? Bool ?? true
    }

    /// Set subscription override for debugging (only works in dev mode)
    func setSubscriptionOverride(enabled: Bool, value: Bool) {
        #if DEBUG
        subscriptionOverrideEnabled = enabled
        subscriptionOverrideValue = value
        // Trigger UI update by publishing change
        objectWillChange.send()
        #endif
    }

    private func setupAuthStateListener() {
        #if DEBUG
        // Debug auth bypass - check UserDefaults for debug mock user flag
        if UserDefaults.standard.bool(forKey: "debug_use_mock_user") {
            let mockUser = User(
                id: "debug-user-123",
                name: "Debug User",
                email: "debug@rushday.test",
                photoUrl: nil,
                currency: "USD",
                isPremium: true,
                createAt: Date(),
                updateAt: nil,
                events: ["debug-event-123"],
                notificationConfiguration: nil
            )
            self.currentUser = mockUser
            self.authState = .authenticated(mockUser)
            self.hasCompletedOnboarding = true
            self.currentRoute = .home
            // Load mock events
            Task {
                await self.loadMockEventsForDebug()
            }
            return
        }
        #endif

        // Listen for auth state changes - Firebase will fire this immediately with the current state
        // and again whenever auth state changes
        authStateHandle = authService.addAuthStateListener { [weak self] user in
            Task { @MainActor in
                guard let self = self else { return }

                // If we're still in unknown state, wait a moment for Firebase to restore session
                if self.authState == .unknown {
                    // Small delay to allow Firebase to restore session from Keychain
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // Check again after delay - use currentUser which might be updated
                    if let currentUser = self.authService.currentUser {
                        self.updateAuthenticatedState(currentUser)
                    } else if let user = user {
                        self.updateAuthenticatedState(user)
                    } else {
                        self.authState = .unauthenticated
                        self.currentRoute = .auth
                    }
                } else {
                    // Normal auth state change (not initial)
                    if let user = user {
                        self.updateAuthenticatedState(user)
                    } else {
                        self.authState = .unauthenticated
                        self.currentRoute = .auth
                        // Clear gRPC token when user logs out
                        GRPCClientService.shared.setAuthToken(nil)
                    }
                }
            }
        }
    }

    private func updateAuthenticatedState(_ user: User) {
        let wasAlreadyAuthenticated: Bool
        if case .authenticated = authState {
            wasAlreadyAuthenticated = true
        } else {
            wasAlreadyAuthenticated = false
        }

        currentUser = user
        authState = .authenticated(user)

        // Set AppsFlyer user ID for attribution tracking
        AppsFlyerService.shared.setUserId(user.id)

        // Only navigate to home if this is a fresh login, not a token refresh
        if !wasAlreadyAuthenticated {
            // Check if there's a pending deep link - process it first before any other flow
            if pendingDeepLink != nil || pendingCoHostSecret != nil {
                // Set gRPC auth token and process deep link
                Task {
                    await refreshGRPCAuthToken()
                    await performMigrationIfNeeded()
                    await loadCurrentUser() // Load full user profile from backend
                    await registerDeviceWithBackend()
                    // Process the pending deep link (this will show invitation dialog for co-host invites)
                    processPendingDeepLink()
                }
                currentRoute = .home
                return
            }

            // If signing in from AI planner, don't navigate - the planner will handle the flow
            if isSigningInFromAIPlanner || showAIEventPlanner {
                // Set gRPC auth token but don't navigate
                Task {
                    await refreshGRPCAuthToken()
                    await performMigrationIfNeeded()
                    await loadCurrentUser() // Load full user profile from backend
                    await registerDeviceWithBackend()
                }
                return
            }

            // Check if we have pending event data from AI planner
            // If so, show paywall flow instead of going directly to home
            handlePostAuthWithPendingEvent()

            if !showAIEventPreviewAfterAuth {
                currentRoute = .home
            }

            // Set gRPC auth token when user logs in
            Task {
                await refreshGRPCAuthToken()
                await performMigrationIfNeeded()
                await loadCurrentUser() // Load full user profile from backend
                await registerDeviceWithBackend()
            }
        }
    }

    private func loadOnboardingState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    func signOut() {
        do {
            try authService.signOut()
            currentUser = nil
            authState = .unauthenticated
            currentRoute = .auth
            // Don't show AI planner on sign out - user might want to sign into different account
            showAIEventPlanner = false
            // Clear AppsFlyer user ID
            AppsFlyerService.shared.clearUserId()
        } catch {
            // Sign out failed silently
        }
    }

    /// Called when user deletes their account
    func handleAccountDeleted() {
        // Sign out from Firebase
        try? authService.signOut()
        // Clear gRPC token
        GRPCClientService.shared.setAuthToken(nil)

        currentUser = nil
        authState = .unauthenticated
        currentRoute = .auth
        // Show AI planner since user is starting fresh
        if hasCompletedOnboarding {
            showAIEventPlanner = true
        }
    }

    func updateUser(_ user: User) {
        currentUser = user
        authState = .authenticated(user)
    }

    func handleSuccessfulSignIn(user: User, isNewUser: Bool) {
        currentUser = user
        authState = .authenticated(user)

        // If signing in from AI planner, don't navigate - the planner will handle the flow
        if isSigningInFromAIPlanner || showAIEventPlanner {
            isSigningInFromAIPlanner = false
            // Set gRPC auth token and load full user profile
            Task {
                await refreshGRPCAuthToken()
                await loadCurrentUser()
            }
            return
        }

        // If we have pending AI planner data, don't navigate - let the planner complete
        if pendingEventData != nil {
            Task {
                await refreshGRPCAuthToken()
                await loadCurrentUser()
            }
            return
        }

        if isNewUser {
            currentRoute = .home
            // Mark onboarding as completed since they've logged in
            completeOnboarding()
            // Load full user profile from backend
            Task {
                await refreshGRPCAuthToken()
                await loadCurrentUser()
            }
        } else {
            currentRoute = .home
            // Trigger migration for existing users and load profile
            Task {
                await refreshGRPCAuthToken()
                await performMigrationIfNeeded()
                await loadCurrentUser()
            }
        }
    }

    // MARK: - AI Event Planner Flow Methods

    /// Called when onboarding is completed to show AI Event Planner
    func showAIPlanner() {
        showAIEventPlanner = true
    }

    /// Called when AI Event Planner is completed (user selected a plan)
    func completeAIPlanner(with data: PendingEventData) {
        pendingEventData = data
        showAIEventPlanner = false
        // Reset the shared ViewModel for next time
        AIEventPlannerViewModel.shared.resetState()

        // If user is already authenticated (signed in from AI planner), show preview immediately
        if case .authenticated = authState {
            showAIEventPreviewAfterAuth = true
        }
        // Otherwise, user will go to auth and handlePostAuthWithPendingEvent will set this flag
    }

    /// Called after successful authentication when there's pending event data
    func handlePostAuthWithPendingEvent() {
        if pendingEventData != nil {
            // Show AI Event Preview screen
            showAIEventPreviewAfterAuth = true
        }
    }

    /// Called when AI Event Preview flow is completed (event created or dismissed)
    func completeAIEventPreviewFlow() {
        showAIEventPreviewAfterAuth = false
        // Create event from pending data
        if pendingEventData != nil {
            // Event will be created by the view that handles this
            // Clear pending data after event is created
        }
        currentRoute = .home
    }

    /// Clear pending event data after event is created
    func clearPendingEventData() {
        pendingEventData = nil
    }

    /// Clear all cached event data and reload (for testing shimmer loading states)
    @Published var shouldReloadApp = false

    func clearAllEventCacheAndReload() {
        // Clear all cached data
        events = []
        tasksByEvent = [:]
        guestsByEvent = [:]
        agendaByEvent = [:]
        expensesByEvent = [:]
        budgetByEvent = [:]

        // Close all debug sheets first
        #if DEBUG
        showDebugConsole = false
        showDebugProfile = false
        showDebugGuests = false
        showDebugTasks = false
        showDebugAgenda = false
        showDebugExpenses = false
        showDebugInvitationPreview = false
        showDebugEditEvent = false
        showDebugNotificationSettings = false
        showDebugEditTask = false
        showDebugBudgetEditor = false
        #endif

        // Trigger app reload after a brief delay to allow sheets to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.shouldReloadApp = true
        }
    }

    /// Cancel AI planner flow
    func cancelAIPlannerFlow() {
        showAIEventPlanner = false
        pendingEventData = nil
        // Reset the shared ViewModel for next time
        AIEventPlannerViewModel.shared.resetState()
    }

    // MARK: - Device Registration

    /// Registers for push notifications and sends the FCM token to the backend
    func registerDeviceWithBackend() async {
        do {
            // Get FCM token from notification service
            guard let fcmToken = try await notificationService.registerForPushNotifications() else {
                return
            }

            // Build request with available fields
            var request = Rushday_V1_RegisterDeviceRequest()
            request.fcmToken = fcmToken
            request.platform = "ios"
            request.timezoneOffset = Int32(TimeZone.current.secondsFromGMT() / 60) // offset in minutes

            // Register with backend
            _ = try await GRPCClientService.shared.registerDevice(request)
        } catch {
            // Error handled silently
        }
    }

    // MARK: - Migration

    /// Performs data migration from Firestore to gRPC backend if needed
    func performMigrationIfNeeded() async {
        print("📦 [Migration] Starting migration check...")

        // ALWAYS call getCurrentUser first - this auto-creates the user if they don't exist
        // This is critical for new users who just signed up via Firebase
        do {
            let user = try await GRPCClientService.shared.getCurrentUser()
            print("📦 [Migration] getCurrentUser succeeded — uid: \(user.id)")
        } catch {
            print("📦 [Migration] getCurrentUser failed: \(error.localizedDescription) — continuing anyway")
        }

        // If already migrated, we're done
        if migrationService.hasMigrated {
            print("📦 [Migration] Already migrated (version: \(migrationService.lastMigrationVersion ?? "unknown")) — skipping")
            return
        }

        print("📦 [Migration] Not yet migrated — starting migration...")
        isMigrating = true
        migrationError = nil

        do {
            if let result = try await migrationService.migrateUserDataIfNeeded() {
                if result.success || result.alreadyMigrated {
                    print("📦 [Migration] ✅ Completed — alreadyMigrated: \(result.alreadyMigrated)")
                } else {
                    print("📦 [Migration] ❌ Failed — \(result.message)")
                    migrationError = result.message
                }
                if let stats = result.stats {
                    print("📦 [Migration] Stats:")
                    print("📦   Events:   \(stats.eventsMigrated)")
                    print("📦   Tasks:    \(stats.tasksMigrated)")
                    print("📦   Guests:   \(stats.guestsMigrated)")
                    print("📦   Agendas:  \(stats.agendasMigrated)")
                    print("📦   Expenses: \(stats.expensesMigrated)")
                    print("📦   Vendors:  \(stats.vendorsMigrated)")
                    print("📦   Devices:  \(stats.devicesMigrated)")
                    print("📦   Total:    \(stats.totalItemsMigrated)")
                }
            } else {
                print("📦 [Migration] Skipped (already migrated locally)")
            }
        } catch {
            print("📦 [Migration] ❌ Error: \(error.localizedDescription)")
            migrationError = error.localizedDescription
        }

        isMigrating = false
        print("📦 [Migration] Done")
    }

    /// Force migration (useful for debugging or retry)
    func forceMigration() async {
        print("📦 [Migration] Force migration triggered")
        isMigrating = true
        migrationError = nil

        do {
            let result = try await migrationService.forceMigration()
            if result.success || result.alreadyMigrated {
                print("📦 [Migration] ✅ Force migration completed — alreadyMigrated: \(result.alreadyMigrated)")
            } else {
                print("📦 [Migration] ❌ Force migration failed — \(result.message)")
                migrationError = result.message
            }
            if let stats = result.stats {
                print("📦 [Migration] Stats:")
                print("📦   Events:   \(stats.eventsMigrated)")
                print("📦   Tasks:    \(stats.tasksMigrated)")
                print("📦   Guests:   \(stats.guestsMigrated)")
                print("📦   Agendas:  \(stats.agendasMigrated)")
                print("📦   Expenses: \(stats.expensesMigrated)")
                print("📦   Vendors:  \(stats.vendorsMigrated)")
                print("📦   Devices:  \(stats.devicesMigrated)")
                print("📦   Total:    \(stats.totalItemsMigrated)")
            }
        } catch {
            print("📦 [Migration] ❌ Force migration error: \(error.localizedDescription)")
            migrationError = error.localizedDescription
        }

        isMigrating = false
        print("📦 [Migration] Force migration done")
    }

    // MARK: - Deep Link Handling

    /// Handle an incoming deep link
    func handleDeepLink(_ deepLink: DeepLinkType) {
        #if DEBUG
        // Allow debug screens without authentication
        if case .debugScreen(let name) = deepLink {
            handleDebugScreenDeepLink(name: name)
            return
        }
        #endif

        // If not authenticated, save for later
        guard case .authenticated = authState else {
            pendingDeepLink = deepLink
            return
        }

        // Process the deep link
        processDeepLink(deepLink)
    }

    /// Process a deep link after authentication
    private func processDeepLink(_ deepLink: DeepLinkType) {
        Task {
            switch deepLink {
            case .invitation(let id):   
                await handleInvitationDeepLink(invitationId: id)

            case .guest(let id):
                await handleInvitationDeepLink(invitationId: id)

            case .event(let id):
                await handleEventDeepLink(eventId: id)

            case .coHostInvite(let secret):
                await handleCoHostInviteDeepLink(secret: secret)

            case .debugScreen(let name):
                #if DEBUG
                handleDebugScreenDeepLink(name: name)
                #else
                _ = name // Silence unused variable warning in release
                #endif

            case .unknown:
                break
            }
        }
    }

    // MARK: - Debug Screen Deep Link (DEBUG only)

    #if DEBUG
    /// Handle debug screen deep link for testing UI screens
    /// Usage: rushday://debug/{screenName} or rushday://screen/{screenName}
    private func handleDebugScreenDeepLink(name: String) {
        switch name.lowercased() {
        // MARK: Full-screen overlays
        case "paywall":
            showDebugPaywall = true

        case "feature-paywall", "featurepaywall", "feature_paywall":
            showDebugFeaturePaywall = true

        case "onboarding":
            showDebugOnboarding = true

        case "ai-planner", "aiplanner", "ai_planner":
            showDebugAIPlanner = true

        case "auth", "login", "signin", "sign-in":
            showDebugAuth = true

        case "profile":
            showDebugProfile = true

        case "console", "debug-console", "debugconsole":
            showDebugConsole = true

        case "notification-settings", "notificationsettings", "notification_settings":
            showDebugNotificationSettings = true

        // MARK: Navigation routes
        case "settings":
            currentRoute = .settings

        case "home":
            currentRoute = .home

        case "create-event", "createevent", "create_event":
            currentRoute = .createEvent

        // MARK: Event-dependent screens (uses first event)
        case "event-details", "eventdetails", "event_details":
            loadFirstEventAndNavigate { event in
                self.navigateToEvent = event
            }

        case "guests":
            loadFirstEventAndShow { self.showDebugGuests = true }

        case "tasks":
            loadFirstEventAndShow { self.showDebugTasks = true }

        case "agenda":
            loadFirstEventAndShow { self.showDebugAgenda = true }

        case "expenses":
            loadFirstEventAndShow { self.showDebugExpenses = true }

        case "invitation-preview", "invitationpreview", "invitation_preview":
            loadFirstEventAndShow { self.showDebugInvitationPreview = true }

        case "edit-event", "editevent", "edit_event":
            loadFirstEventAndShow { self.showDebugEditEvent = true }

        case "edit-task", "edittask", "edit_task":
            // Create mock event for direct testing without backend
            let mockEvent = Event(
                id: "debug-mock-event",
                name: "Debug Event",
                startDate: Date(),
                createAt: Date(),
                eventTypeId: EventType.birthday.rawValue,
                ownerId: "debug-user"
            )
            self.debugEvent = mockEvent
            self.showDebugEditTask = true

        case "budget-editor", "budgeteditor", "budget_editor":
            self.showDebugBudgetEditor = true

        default:
            print("Debug screen not found: \(name)")
            print("Available screens: paywall, feature-paywall, onboarding, ai-planner, profile, console, notification-settings, settings, home, create-event, event-details, guests, tasks, agenda, expenses, invitation-preview, edit-event")
        }

        // Track analytics
        AnalyticsService.shared.logEvent("debug_screen_opened", parameters: [
            "screen_name": name
        ])
    }

    /// Helper to load first event and execute action with it
    private func loadFirstEventAndNavigate(action: @escaping (Event) -> Void) {
        Task {
            do {
                let response = try await GRPCClientService.shared.listEvents()
                if let firstGrpcEvent = response.events.first {
                    let event = Event(from: firstGrpcEvent)
                    await MainActor.run {
                        action(event)
                    }
                } else {
                    print("No events found for debug screen")
                }
            } catch {
                print("Failed to fetch events for debug: \(error)")
            }
        }
    }

    /// Helper to load first event and show a debug screen
    private func loadFirstEventAndShow(showAction: @escaping () -> Void) {
        Task {
            do {
                let response = try await GRPCClientService.shared.listEvents()
                if let firstGrpcEvent = response.events.first {
                    let event = Event(from: firstGrpcEvent)
                    await MainActor.run {
                        self.debugEvent = event
                        showAction()
                    }
                } else {
                    print("No events found for debug screen")
                }
            } catch {
                print("Failed to fetch events for debug: \(error)")
            }
        }
    }
    #endif

    /// Handle invitation deep link
    private func handleInvitationDeepLink(invitationId: String) async {
        do {
            // Fetch the public invitation details
            let publicInvitation = try await GRPCClientService.shared.getPublicInvitation(id: invitationId)

            // Create a temporary event from the invitation for display
            let event = Event(
                id: "",
                name: publicInvitation.name,
                startDate: publicInvitation.date.date,
                eventType: .custom,
                ownerId: "",
                venue: publicInvitation.location,
                coverImage: publicInvitation.image
            )

            invitationEvent = event
            showInvitationDialog = true

        } catch {
            // Error handled silently
        }
    }

    /// Handle event deep link (direct event access)
    private func handleEventDeepLink(eventId: String) async {
        // Navigate to event details
        currentRoute = .eventDetails(eventId: eventId)
    }

    /// Handle co-host invite deep link (shared event invitation with one-time secret)
    private func handleCoHostInviteDeepLink(secret: String) async {
        // Store the secret for later use in acceptInvitation()
        pendingCoHostSecret = secret

        // Note: We can't fetch event details without the secret being accepted first
        // The dialog will show generic invitation message
        // Event details will be available after accepting

        // Show the invitation dialog
        showInvitationDialog = true

        // Track analytics (don't log full secret for privacy)
        AnalyticsService.shared.logEvent("co_host_invite_received", parameters: [
            "secret_prefix": String(secret.prefix(8))
        ])
    }

    /// Accept the current invitation (handles both public guest invitations and co-host invitations)
    func acceptInvitation() {
        // Check if this is a co-host invitation (has pending secret)
        if let secret = pendingCoHostSecret {
            acceptCoHostInvitation(secret: secret)
            return
        }

        // Handle public guest invitation (invitationEvent set)
        guard let event = invitationEvent else { return }

        // Navigate to event details
        currentRoute = .eventDetails(eventId: event.id)

        // Clear dialog state
        clearInvitationDialog()

        // Track analytics
        AnalyticsService.shared.logEvent("invitation_accepted", parameters: [
            "event_id": event.id
        ])
    }

    /// Accept a co-host invitation using the one-time secret token
    /// This calls the backend to accept the invitation, which:
    /// 1. Adds the current user as a co-host to the event
    /// 2. Invalidates the secret (one-time use)
    /// 3. Returns the event data
    private func acceptCoHostInvitation(secret: String) {
        isLoading = true

        // Clear dialog state immediately
        clearInvitationDialog()

        Task {
            do {
                // Call backend to accept the invitation using the secret
                // This grants access to the event and invalidates the link
                let grpcEvent = try await GRPCClientService.shared.acceptSharedEvent(secret: secret)

                // Convert to domain Event
                let event = Event(from: grpcEvent)

                // Check if the current user is the owner of the event
                // User cannot be a co-host of their own event
                if let userId = currentUser?.id, userId == event.ownerId {
                    await MainActor.run {
                        isLoading = false
                        errorAlertMessage = L10n.cannotCoHostOwnEvent
                        showErrorAlert = true
                    }

                    // Track analytics
                    AnalyticsService.shared.logEvent("co_host_invitation_self_rejected", parameters: [
                        "event_id": event.id
                    ])
                    return
                }

                await MainActor.run {
                    // Navigate to the event
                    navigateToEvent = event
                    isLoading = false
                }

                // Track analytics
                AnalyticsService.shared.logEvent("co_host_invitation_accepted", parameters: [
                    "event_id": event.id
                ])

                // Note: Notification to owner is sent by the backend

                // Reload events to include the newly joined event
                await loadEvents()

            } catch {
                await MainActor.run {
                    isLoading = false
                }

                // Track analytics
                AnalyticsService.shared.logEvent("co_host_invitation_failed", parameters: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    /// Decline the current invitation
    func declineInvitation() {
        // Clear dialog state
        clearInvitationDialog()

        // Track analytics
        if let event = invitationEvent {
            AnalyticsService.shared.logEvent("invitation_declined", parameters: [
                "event_id": event.id
            ])
        }
    }

    /// Clear invitation dialog state
    private func clearInvitationDialog() {
        showInvitationDialog = false
        invitationEvent = nil
        pendingCoHostSecret = nil
    }

    /// Process any pending deep link after authentication
    func processPendingDeepLink() {
        guard let deepLink = pendingDeepLink else { return }
        pendingDeepLink = nil
        processDeepLink(deepLink)
    }

    // MARK: - Debug Mock Data

    #if DEBUG
    /// Load mock events for debug mode (when using mock user)
    private func loadMockEventsForDebug() async {
        let mockEvent = Event(
            id: "debug-event-123",
            name: "Debug Test Event",
            startDate: Date().addingTimeInterval(86400 * 7), // 1 week from now
            createAt: Date(),
            eventTypeId: EventType.birthday.rawValue,
            ownerId: "debug-user-123",
            ownerName: "Debug User",
            isAllDay: false,
            isMovedToDraft: false,
            endDate: nil,
            venue: "Test Venue, San Francisco",
            customIdea: "This is a debug test event for UI testing",
            themeIdea: nil,
            coverImage: "https://images.unsplash.com/photo-1530103862676-de8c9debad1d?w=800",
            inviteMessage: "You're invited to the test event!",
            updatedAt: Date(),
            shared: []
        )
        self.events = [mockEvent]
        self.debugEvent = mockEvent
    }
    #endif

    // MARK: - Events Store Methods

    /// Load all events from backend using streaming for progressive loading
    /// Events are loaded in batches of 2, showing data progressively on the home page
    func loadEvents() async {
        isLoadingEvents = true

        // Clear events before streaming to show fresh data
        var loadedEvents: [Event] = []
        var loadedDraftEvents: [Event] = []

        do {
            // Use streaming for progressive loading
            for try await response in GRPCClientService.shared.streamEvents(batchSize: 2) {
                let batchEvents = response.toDomainEvents()

                // Separate drafts from regular events
                let regularBatch = batchEvents.filter { !$0.isMovedToDraft }
                let draftBatch = batchEvents.filter { $0.isMovedToDraft }

                loadedEvents.append(contentsOf: regularBatch)
                loadedDraftEvents.append(contentsOf: draftBatch)

                // Update UI immediately with each batch
                events = loadedEvents
                draftEvents = loadedDraftEvents

                if response.isLast {
                    break
                }
            }
        } catch {
            // Fallback to non-streaming method if streaming fails
            do {
                let response = try await GRPCClientService.shared.listEvents(page: 1, limit: 100)
                let allEvents = response.toDomainEvents()
                events = allEvents.filter { !$0.isMovedToDraft }
                draftEvents = allEvents.filter { $0.isMovedToDraft }
            } catch {
                // Error handled silently
            }
        }

        isLoadingEvents = false
    }

    /// Get event by ID from the local store
    func getEvent(id: String) -> Event? {
        return events.first(where: { $0.id == id }) ?? draftEvents.first(where: { $0.id == id })
    }

    /// Update an event in the local store (call after editing)
    func updateEvent(_ updatedEvent: Event) {
        if let index = events.firstIndex(where: { $0.id == updatedEvent.id }) {
            events[index] = updatedEvent
        } else if let index = draftEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
            draftEvents[index] = updatedEvent
        }
    }

    /// Add a new event to the store
    func addEvent(_ event: Event) {
        if event.isMovedToDraft {
            draftEvents.insert(event, at: 0)
        } else {
            events.insert(event, at: 0)
        }
    }

    /// Remove an event from the store
    func removeEvent(id: String) {
        events.removeAll { $0.id == id }
        draftEvents.removeAll { $0.id == id }
    }

    /// Move an event to drafts
    func moveEventToDrafts(id: String) {
        if let index = events.firstIndex(where: { $0.id == id }) {
            var event = events.remove(at: index)
            event.isMovedToDraft = true
            draftEvents.insert(event, at: 0)
        }
    }

    /// Restore an event from drafts
    func restoreEventFromDrafts(id: String) {
        if let index = draftEvents.firstIndex(where: { $0.id == id }) {
            var event = draftEvents.remove(at: index)
            event.isMovedToDraft = false
            events.insert(event, at: 0)
        }
    }

    /// Get upcoming events (sorted by date)
    var upcomingEvents: [Event] {
        events.filter { $0.isUpcoming }.sorted { $0.startDate < $1.startDate }
    }

    /// Get past events (sorted by date descending)
    var pastEvents: [Event] {
        events.filter { $0.isPast }.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Guests Store Methods

    /// Setup listener for guest refresh notifications (from push notifications)
    private func setupGuestRefreshListener() {
        guestRefreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshGuestData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let eventId = notification.userInfo?["eventId"] as? String {
                Task { @MainActor in
                    await self.refreshGuests(for: eventId)
                }
            }
        }
    }

    /// Setup listener for event refresh notifications (from push notifications)
    private func setupEventRefreshListener() {
        eventRefreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshEventData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { @MainActor in
                // Check if this is a removal notification
                let type = notification.userInfo?["type"] as? String
                let isRemoval = type == "co_host_removed" || type == "cohost_removed" || type == "shared_event_removed"

                if isRemoval, let eventId = notification.userInfo?["eventId"] as? String {
                    // Immediately remove the event from the list for removed co-host
                    self.events.removeAll { $0.id == eventId }
                    self.guestsByEvent.removeValue(forKey: eventId)
                } else if let eventId = notification.userInfo?["eventId"] as? String {
                    // Refresh only the specific event
                    await self.refreshEvent(id: eventId)
                } else {
                    // No specific eventId - refresh all events
                    await self.loadEvents()
                }
            }
        }
    }

    /// Refresh a specific event from the backend
    func refreshEvent(id: String) async {
        do {
            let grpcEvent = try await GRPCClientService.shared.getEvent(id: id)
            let updatedEvent = Event(from: grpcEvent)

            // Update in events array
            if let index = events.firstIndex(where: { $0.id == id }) {
                events[index] = updatedEvent
            }
        } catch {
            // Event might have been deleted or user lost access
            // Remove it from the list
            events.removeAll { $0.id == id }
            guestsByEvent.removeValue(forKey: id)
        }
    }

    /// Get guests for an event from the store
    func guests(for eventId: String) -> [Guest] {
        return guestsByEvent[eventId] ?? []
    }

    /// Get a specific guest by ID from the store
    func guest(id: String, eventId: String) -> Guest? {
        return guestsByEvent[eventId]?.first { $0.id == id }
    }

    /// Load guests for an event (fetches from backend if not cached)
    func loadGuests(for eventId: String) async {
        guard !isLoadingGuests.contains(eventId) else { return }

        isLoadingGuests.insert(eventId)
        defer { isLoadingGuests.remove(eventId) }

        do {
            let guestRepository = DIContainer.shared.guestRepository
            let guests = try await guestRepository.getGuestsForEvent(eventId: eventId)
            guestsByEvent[eventId] = guests
        } catch {
            // Error handled silently
        }
    }

    /// Refresh guests for an event (called when push notification arrives)
    func refreshGuests(for eventId: String) async {
        do {
            let guestRepository = DIContainer.shared.guestRepository
            let guests = try await guestRepository.getGuestsForEvent(eventId: eventId)
            guestsByEvent[eventId] = guests
        } catch {
            // Error handled silently
        }
    }

    /// Update a single guest in the store (for local edits)
    func updateGuest(_ guest: Guest, eventId: String) {
        guard var guests = guestsByEvent[eventId] else { return }
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index] = guest
            guestsByEvent[eventId] = guests
        }
    }

    /// Add a guest to the store
    func addGuest(_ guest: Guest, eventId: String) {
        var guests = guestsByEvent[eventId] ?? []
        guests.append(guest)
        guestsByEvent[eventId] = guests
    }

    /// Add multiple guests to the store
    func addGuests(_ newGuests: [Guest], eventId: String) {
        var guests = guestsByEvent[eventId] ?? []
        guests.append(contentsOf: newGuests)
        guestsByEvent[eventId] = guests
    }

    /// Remove a guest from the store
    func removeGuest(id: String, eventId: String) {
        guard var guests = guestsByEvent[eventId] else { return }
        guests.removeAll { $0.id == id }
        guestsByEvent[eventId] = guests
    }

    /// Remove multiple guests from the store
    func removeGuests(ids: Set<String>, eventId: String) {
        guard var guests = guestsByEvent[eventId] else { return }
        guests.removeAll { ids.contains($0.id) }
        guestsByEvent[eventId] = guests
    }

    /// Clear cached guests for an event
    func clearGuestCache(for eventId: String) {
        guestsByEvent.removeValue(forKey: eventId)
    }

    // MARK: - Expenses Store Methods

    /// Setup listener for expense refresh notifications (from push notifications)
    private func setupExpenseRefreshListener() {
        expenseRefreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshExpenseData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let eventId = notification.userInfo?["eventId"] as? String {
                Task { @MainActor in
                    await self.refreshExpenses(for: eventId)
                }
            }
        }
    }

    /// Get expenses for an event from the store
    func expenses(for eventId: String) -> [Expense] {
        return expensesByEvent[eventId] ?? []
    }

    /// Get budget for an event from the store
    func budget(for eventId: String) -> Double {
        return budgetByEvent[eventId] ?? 0
    }

    /// Load expenses for an event (fetches from backend if not cached)
    func loadExpenses(for eventId: String) async {
        guard !isLoadingExpenses.contains(eventId) else { return }

        isLoadingExpenses.insert(eventId)
        defer { isLoadingExpenses.remove(eventId) }

        do {
            let expenseRepository = DIContainer.shared.expenseRepository
            let expenses = try await expenseRepository.getExpensesForEvent(eventId: eventId)
            expensesByEvent[eventId] = expenses

            // Also load budget
            do {
                let eventBudget = try await GRPCClientService.shared.getEventBudget(eventId: eventId)
                budgetByEvent[eventId] = eventBudget.plannedBudget
            } catch {
                // Budget may not exist yet
            }
        } catch {
            // Error handled silently
        }
    }

    /// Refresh expenses for an event (called when push notification arrives)
    func refreshExpenses(for eventId: String) async {
        do {
            let expenseRepository = DIContainer.shared.expenseRepository
            let expenses = try await expenseRepository.getExpensesForEvent(eventId: eventId)
            withAnimation(.easeInOut(duration: 0.2)) {
                expensesByEvent[eventId] = expenses
            }

            // Also refresh budget
            do {
                let eventBudget = try await GRPCClientService.shared.getEventBudget(eventId: eventId)
                withAnimation(.easeInOut(duration: 0.2)) {
                    budgetByEvent[eventId] = eventBudget.plannedBudget
                }
            } catch {
                // Budget may not exist yet
            }
        } catch {
            // Error handled silently
        }
    }

    /// Update a single expense in the store (for local edits)
    func updateExpense(_ expense: Expense, eventId: String) {
        guard var expenses = expensesByEvent[eventId] else { return }
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            expensesByEvent[eventId] = expenses
        }
    }

    /// Add an expense to the store
    func addExpense(_ expense: Expense, eventId: String) {
        var expenses = expensesByEvent[eventId] ?? []
        expenses.append(expense)
        expensesByEvent[eventId] = expenses
    }

    /// Remove an expense from the store
    func removeExpense(id: String, eventId: String) {
        guard var expenses = expensesByEvent[eventId] else { return }
        expenses.removeAll { $0.id == id }
        expensesByEvent[eventId] = expenses
    }

    /// Remove multiple expenses from the store
    func removeExpenses(ids: Set<String>, eventId: String) {
        guard var expenses = expensesByEvent[eventId] else { return }
        expenses.removeAll { ids.contains($0.id) }
        expensesByEvent[eventId] = expenses
    }

    /// Update budget for an event
    func updateBudget(_ budget: Double, eventId: String) {
        budgetByEvent[eventId] = budget
    }

    /// Clear cached expenses for an event
    func clearExpenseCache(for eventId: String) {
        expensesByEvent.removeValue(forKey: eventId)
        budgetByEvent.removeValue(forKey: eventId)
    }

    // MARK: - Agenda Store Methods

    /// Setup listener for agenda refresh notifications (from push notifications)
    private func setupAgendaRefreshListener() {
        agendaRefreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshAgendaData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let eventId = notification.userInfo?["eventId"] as? String {
                Task { @MainActor in
                    await self.refreshAgenda(for: eventId)
                }
            }
        }
    }

    /// Get agenda items for an event from the store
    func agendaItems(for eventId: String) -> [AgendaItem] {
        return agendaByEvent[eventId] ?? []
    }

    /// Load agenda items for an event (fetches from backend if not cached)
    func loadAgenda(for eventId: String, eventDate: Date) async {
        guard !isLoadingAgenda.contains(eventId) else { return }

        isLoadingAgenda.insert(eventId)
        defer { isLoadingAgenda.remove(eventId) }

        do {
            let agendaRepository = DIContainer.shared.agendaRepository
            let items = try await agendaRepository.getAgendaForEvent(eventId: eventId)
            withAnimation(.easeInOut(duration: 0.2)) {
                agendaByEvent[eventId] = items
            }
        } catch {
            // Error handled silently
        }
    }

    /// Refresh agenda items for an event (called when push notification arrives)
    func refreshAgenda(for eventId: String) async {
        do {
            let agendaRepository = DIContainer.shared.agendaRepository
            let items = try await agendaRepository.getAgendaForEvent(eventId: eventId)
            withAnimation(.easeInOut(duration: 0.2)) {
                agendaByEvent[eventId] = items
            }
        } catch {
            // Error handled silently
        }
    }

    /// Update a single agenda item in the store (for local edits)
    func updateAgendaItem(_ item: AgendaItem, eventId: String) {
        guard var items = agendaByEvent[eventId] else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            agendaByEvent[eventId] = items
        }
    }

    /// Add an agenda item to the store
    func addAgendaItem(_ item: AgendaItem, eventId: String) {
        var items = agendaByEvent[eventId] ?? []
        items.append(item)
        agendaByEvent[eventId] = items
    }

    /// Remove an agenda item from the store
    func removeAgendaItem(id: String, eventId: String) {
        guard var items = agendaByEvent[eventId] else { return }
        items.removeAll { $0.id == id }
        agendaByEvent[eventId] = items
    }

    /// Remove multiple agenda items from the store
    func removeAgendaItems(ids: Set<String>, eventId: String) {
        guard var items = agendaByEvent[eventId] else { return }
        items.removeAll { ids.contains($0.id) }
        agendaByEvent[eventId] = items
    }

    /// Clear cached agenda items for an event
    func clearAgendaCache(for eventId: String) {
        agendaByEvent.removeValue(forKey: eventId)
    }

    // MARK: - Tasks Store Methods

    /// Setup listener for task refresh notifications (from push notifications)
    private func setupTaskRefreshListener() {
        taskRefreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshTaskData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let eventId = notification.userInfo?["eventId"] as? String {
                Task { @MainActor in
                    await self.refreshTasks(for: eventId)
                }
            }
        }
    }

    /// Get tasks for an event from the store
    func tasks(for eventId: String) -> [EventTask] {
        return tasksByEvent[eventId] ?? []
    }

    /// Load tasks for an event (fetches from backend if not cached)
    func loadTasks(for eventId: String) async {
        guard !isLoadingTasks.contains(eventId) else { return }

        isLoadingTasks.insert(eventId)
        defer { isLoadingTasks.remove(eventId) }

        do {
            let taskRepository = DIContainer.shared.taskRepository
            let loadedTasks = try await taskRepository.getTasksForEvent(eventId: eventId)
            withAnimation(.easeInOut(duration: 0.2)) {
                tasksByEvent[eventId] = loadedTasks
            }
        } catch {
            // Error handled silently
        }
    }

    /// Refresh tasks for an event (called when push notification arrives)
    func refreshTasks(for eventId: String) async {
        do {
            let taskRepository = DIContainer.shared.taskRepository
            let loadedTasks = try await taskRepository.getTasksForEvent(eventId: eventId)
            withAnimation(.easeInOut(duration: 0.2)) {
                tasksByEvent[eventId] = loadedTasks
            }
        } catch {
            // Error handled silently
        }
    }

    /// Update a single task in the store (for local edits)
    func updateTask(_ task: EventTask, eventId: String) {
        guard var tasks = tasksByEvent[eventId] else { return }
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            tasksByEvent[eventId] = tasks
        }
    }

    /// Replace a task with a new one (used when server returns a different ID after creation)
    func replaceTask(oldId: String, with newTask: EventTask, eventId: String) {
        guard var tasks = tasksByEvent[eventId] else { return }
        if let index = tasks.firstIndex(where: { $0.id == oldId }) {
            tasks[index] = newTask
            tasksByEvent[eventId] = tasks
        }
    }

    /// Add a task to the store
    func addTask(_ task: EventTask, eventId: String) {
        var tasks = tasksByEvent[eventId] ?? []
        tasks.append(task)
        tasksByEvent[eventId] = tasks
    }

    /// Remove a task from the store
    func removeTask(id: String, eventId: String) {
        guard var tasks = tasksByEvent[eventId] else { return }
        tasks.removeAll { $0.id == id }
        tasksByEvent[eventId] = tasks
    }

    /// Remove multiple tasks from the store
    func removeTasks(ids: Set<String>, eventId: String) {
        guard var tasks = tasksByEvent[eventId] else { return }
        tasks.removeAll { ids.contains($0.id) }
        tasksByEvent[eventId] = tasks
    }

    /// Clear cached tasks for an event
    func clearTaskCache(for eventId: String) {
        tasksByEvent.removeValue(forKey: eventId)
    }
}
