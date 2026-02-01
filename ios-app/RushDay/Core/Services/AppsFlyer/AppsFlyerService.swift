import Foundation
import AppsFlyerLib

// MARK: - AppsFlyerService

/// Service for AppsFlyer SDK integration and attribution tracking
/// Tracks user acquisition sources and key in-app events for marketing analytics
@MainActor
final class AppsFlyerService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = AppsFlyerService()

    // MARK: - Properties

    private let config = AppConfig.shared
    private var isConfigured = false

    // MARK: - Event Names (matching AppsFlyer standard events)

    enum EventName {
        // Standard AppsFlyer events
        static let purchase = AFEventPurchase
        static let subscribe = AFEventSubscribe
        static let startTrial = AFEventStartTrial
        static let completeRegistration = AFEventCompleteRegistration
        static let login = AFEventLogin

        // Custom events
        static let eventCreated = "event_created"
        static let eventDeleted = "event_deleted"
        static let guestInvited = "guest_invited"
        static let taskCreated = "task_created"
        static let expenseAdded = "expense_added"
        static let coHostInvited = "co_host_invited"
        static let aiPlannerUsed = "ai_planner_used"
        static let invitationShared = "invitation_shared"
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure AppsFlyer SDK - call this in AppDelegate didFinishLaunchingWithOptions
    func configure() {
        guard !isConfigured else { return }

        let appsFlyerLib = AppsFlyerLib.shared()

        // Set dev key and app ID
        appsFlyerLib.appsFlyerDevKey = config.appsFlyerDevKey
        appsFlyerLib.appleAppID = config.appsFlyerAppleAppId

        // Set delegate for conversion data
        appsFlyerLib.delegate = self

        // Enable debug logs in development
        #if DEBUG
        appsFlyerLib.isDebug = true
        #endif

        // Disable IDFA collection (we don't use it)
        appsFlyerLib.disableAdvertisingIdentifier = true

        // Configure OneLink for deep linking
        appsFlyerLib.appInviteOneLinkID = config.appsFlyerOneLinkId

        isConfigured = true

        #if DEBUG
        print("[AppsFlyer] Configured with devKey: \(config.appsFlyerDevKey.prefix(8))...")
        #endif
    }

    /// Start the SDK - call this when app becomes active
    func start() {
        guard isConfigured else {
            configure()
            return
        }

        AppsFlyerLib.shared().start()

        #if DEBUG
        print("[AppsFlyer] SDK started")
        #endif
    }

    /// Set the user ID for attribution (call after user logs in)
    func setUserId(_ userId: String) {
        AppsFlyerLib.shared().customerUserID = userId

        #if DEBUG
        print("[AppsFlyer] User ID set: \(userId.prefix(8))...")
        #endif
    }

    /// Clear user ID on logout
    func clearUserId() {
        AppsFlyerLib.shared().customerUserID = nil
    }

    // MARK: - Standard Events

    /// Log successful registration
    func logRegistration(method: String) {
        logEvent(EventName.completeRegistration, parameters: [
            AFEventParamRegistrationMethod: method
        ])
    }

    /// Log user login
    func logLogin(method: String) {
        logEvent(EventName.login, parameters: [
            "login_method": method
        ])
    }

    /// Log subscription purchase
    func logSubscriptionPurchase(
        productId: String,
        price: Decimal,
        currency: String,
        isTrialConversion: Bool = false
    ) {
        logEvent(EventName.purchase, parameters: [
            AFEventParamContentId: productId,
            AFEventParamRevenue: NSDecimalNumber(decimal: price),
            AFEventParamCurrency: currency,
            AFEventParamContentType: "subscription",
            "is_trial_conversion": isTrialConversion
        ])

        // Also log subscribe event
        logEvent(EventName.subscribe, parameters: [
            AFEventParamContentId: productId,
            AFEventParamRevenue: NSDecimalNumber(decimal: price),
            AFEventParamCurrency: currency
        ])
    }

    /// Log trial start
    func logTrialStart(productId: String) {
        logEvent(EventName.startTrial, parameters: [
            AFEventParamContentId: productId
        ])
    }

    // MARK: - Custom Events

    /// Log event creation
    func logEventCreated(eventType: String, isAIGenerated: Bool = false) {
        logEvent(EventName.eventCreated, parameters: [
            "event_type": eventType,
            "is_ai_generated": isAIGenerated
        ])
    }

    /// Log event deletion
    func logEventDeleted() {
        logEvent(EventName.eventDeleted)
    }

    /// Log guest invited
    func logGuestInvited(count: Int = 1) {
        logEvent(EventName.guestInvited, parameters: [
            AFEventParamQuantity: count
        ])
    }

    /// Log task created
    func logTaskCreated() {
        logEvent(EventName.taskCreated)
    }

    /// Log expense added
    func logExpenseAdded(amount: Double, currency: String = "USD") {
        logEvent(EventName.expenseAdded, parameters: [
            AFEventParamRevenue: amount,
            AFEventParamCurrency: currency
        ])
    }

    /// Log co-host invited
    func logCoHostInvited() {
        logEvent(EventName.coHostInvited)
    }

    /// Log AI planner usage
    func logAIPlannerUsed(eventType: String) {
        logEvent(EventName.aiPlannerUsed, parameters: [
            "event_type": eventType
        ])
    }

    /// Log invitation shared
    func logInvitationShared(method: String) {
        logEvent(EventName.invitationShared, parameters: [
            "share_method": method
        ])
    }

    // MARK: - Generic Event Logging

    /// Log a custom event with optional parameters
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        AppsFlyerLib.shared().logEvent(name, withValues: parameters)

        #if DEBUG
        if let params = parameters {
            print("[AppsFlyer] Event: \(name) - \(params)")
        } else {
            print("[AppsFlyer] Event: \(name)")
        }
        #endif
    }

    // MARK: - Deep Link Handling

    /// Handle incoming URL for AppsFlyer attribution
    func handleOpenURL(_ url: URL) {
        AppsFlyerLib.shared().handleOpen(url)
    }

    /// Handle Universal Link
    func handleUniversalLink(_ userActivity: NSUserActivity) {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }
}

// MARK: - AppsFlyerLibDelegate

extension AppsFlyerService: AppsFlyerLibDelegate {

    /// Called when conversion data is received (install attribution)
    nonisolated func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        // Parse attribution data
        let mediaSource = conversionInfo["media_source"] as? String ?? "organic"
        let campaign = conversionInfo["campaign"] as? String
        let isFirstLaunch = conversionInfo["is_first_launch"] as? Bool ?? false

        #if DEBUG
        print("[AppsFlyer] Conversion data received:")
        print("  - Media Source: \(mediaSource)")
        print("  - Campaign: \(campaign ?? "none")")
        print("  - Is First Launch: \(isFirstLaunch)")
        #endif

        // Store attribution data if needed for analytics
        if isFirstLaunch {
            Task { @MainActor in
                // Could store this data or send to your backend
                AnalyticsService.shared.logEvent("install_attributed", parameters: [
                    "media_source": mediaSource,
                    "campaign": campaign ?? "none"
                ])
            }
        }
    }

    /// Called when conversion data request fails
    nonisolated func onConversionDataFail(_ error: Error) {
        #if DEBUG
        print("[AppsFlyer] Conversion data failed: \(error.localizedDescription)")
        #endif
    }

    /// Called when a deep link is detected (deferred deep linking)
    nonisolated func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        #if DEBUG
        print("[AppsFlyer] Deep link attribution: \(attributionData)")
        #endif

        // Handle deep link data
        if let deepLinkValue = attributionData["deep_link_value"] as? String {
            Task { @MainActor in
                // Parse and handle the deep link
                if let url = URL(string: deepLinkValue) {
                    DeepLinkService.shared.handleURL(url)
                }
            }
        }
    }

    /// Called when deep link attribution fails
    nonisolated func onAppOpenAttributionFailure(_ error: Error) {
        #if DEBUG
        print("[AppsFlyer] Deep link attribution failed: \(error.localizedDescription)")
        #endif
    }
}
