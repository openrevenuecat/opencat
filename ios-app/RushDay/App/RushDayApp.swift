import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications
import AppsFlyerLib

@main
struct RushDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var deepLinkService = DeepLinkService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(localizationManager)
                .id(localizationManager.refreshTrigger)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    handleUserActivity(userActivity)
                }
                .onChange(of: deepLinkService.pendingDeepLink) { _, newValue in
                    if let deepLink = newValue {
                        appState.handleDeepLink(deepLink)
                        deepLinkService.clearPendingDeepLink()
                    }
                }
        }
    }

    /// Handle incoming URL (custom scheme or Universal Link)
    private func handleIncomingURL(_ url: URL) {
        // First try Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        // Pass to AppsFlyer for attribution
        AppsFlyerService.shared.handleOpenURL(url)

        // Then try deep link handling
        if deepLinkService.handleURL(url) {
            return
        }

        // Unhandled URL
    }

    /// Handle Universal Link via NSUserActivity
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        // Pass to AppsFlyer for attribution
        AppsFlyerService.shared.handleUniversalLink(userActivity)

        _ = deepLinkService.handleUserActivity(userActivity)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    // OpenCat API Key — set after registering app via dashboard or API
    private static let openCatAPIKey = "ocat_rushday_dev_key"
    private static let openCatServerUrl = "http://localhost:8080"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase with environment-specific config
        configureFirebase()

        // Log backend configuration
        logBackendConfiguration()

        // Configure Google Sign-In with client ID from GoogleService-Info.plist
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        // Configure OpenCat SDK (replaces RevenueCat)
        #if DEBUG
        OpenCat.setLogLevel(.debug)
        #else
        OpenCat.setLogLevel(.warn)
        #endif
        OpenCat.configureWithServer(
            serverUrl: Self.openCatServerUrl,
            apiKey: Self.openCatAPIKey,
            appUserId: "anonymous_\(UUID().uuidString)"
        )

        // Configure AppsFlyer for attribution tracking
        AppsFlyerService.shared.configure()

        // Set up notification center delegate for foreground notifications
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    /// Start AppsFlyer when app becomes active
    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerService.shared.start()
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass the APNS token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Failed to register for remote notifications
    }

    private func logBackendConfiguration() {
        // Backend configuration logged during app setup
    }

    private func configureFirebase() {
        // NOTE: To use dev Firebase config, register bundle ID io.rushday.event.party.planner
        // in the rushday-dev Firebase project and update GoogleService-Info-Dev.plist
        // For now, always use production Firebase config (rush-day project)
        let configFileName = "GoogleService-Info"

        guard let filePath = Bundle.main.path(forResource: configFileName, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            FirebaseApp.configure()
            return
        }

        FirebaseApp.configure(options: options)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    /// Handle background/silent push notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Parse notification type
        guard let type = userInfo["type"] as? String else {
            completionHandler(.noData)
            return
        }

        // Handle RSVP status updates - trigger data refresh
        if type == "rsvp_status" {
            if let eventId = userInfo["eventId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshGuestData"),
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
            // Also post general refresh
            NotificationCenter.default.post(
                name: Notification.Name("RefreshEventData"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
            completionHandler(.newData)
            return
        }

        // Handle co-host notifications (joined or removed) - trigger event refresh
        // Also handle host_invitation for when co-host accepts (backend may use various type names)
        let coHostTypes = ["co_host_joined", "cohost_joined", "shared_event_accepted", "host_invitation", "co_host_accepted", "co_host_removed", "cohost_removed", "shared_event_removed"]
        if coHostTypes.contains(type) {
            NotificationCenter.default.post(
                name: Notification.Name("RefreshEventData"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
            completionHandler(.newData)
            return
        }

        // Handle expense notifications - trigger expense refresh
        let expenseTypes = ["expense_added", "expense_updated", "expense_deleted", "expense_paid", "expense_unpaid", "budget_updated"]
        if expenseTypes.contains(type) {
            if let eventId = userInfo["eventId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshExpenseData"),
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
            completionHandler(.newData)
            return
        }

        // For any other notification with an eventId, refresh event data as a fallback
        if userInfo["eventId"] != nil {
            NotificationCenter.default.post(
                name: Notification.Name("RefreshEventData"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
            completionHandler(.newData)
            return
        }

        completionHandler(.noData)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let type = userInfo["type"] as? String

        // Trigger data refresh for RSVP notifications
        // Check for type == "rsvp_status" OR presence of eventId (for backwards compatibility)
        if let eventId = userInfo["eventId"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("RefreshGuestData"),
                object: nil,
                userInfo: ["eventId": eventId]
            )
        }

        // Trigger event refresh for co-host notifications (joined or removed)
        let coHostTypes = ["co_host_joined", "cohost_joined", "shared_event_accepted", "host_invitation", "co_host_accepted", "co_host_removed", "cohost_removed", "shared_event_removed"]
        if coHostTypes.contains(type ?? "") {
            NotificationCenter.default.post(
                name: Notification.Name("RefreshEventData"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
        }

        // Trigger expense refresh for expense notifications
        let expenseTypes = ["expense_added", "expense_updated", "expense_deleted", "expense_paid", "expense_unpaid", "budget_updated"]
        if expenseTypes.contains(type ?? "") {
            if let eventId = userInfo["eventId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshExpenseData"),
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
        }

        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap - could navigate to specific screen based on userInfo
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: Notification.Name("NotificationTapped"),
            object: nil,
            userInfo: userInfo
        )

        completionHandler()
    }
}
