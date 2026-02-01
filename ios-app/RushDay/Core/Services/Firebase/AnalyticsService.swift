import Foundation
import FirebaseAnalytics

// MARK: - Analytics Service
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - User Properties

    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    // MARK: - Screen Tracking

    func logScreenView(screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }

    // MARK: - Generic Event Logging

    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    // MARK: - Authentication Events

    func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func logLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func logLogout() {
        logEvent("logout")
    }

    // MARK: - Event Management Events

    func logEventCreated(eventId: String, eventType: String) {
        logEvent("event_created", parameters: [
            "event_id": eventId,
            "event_type": eventType
        ])
    }

    func logEventViewed(eventId: String, eventType: String) {
        logEvent("event_viewed", parameters: [
            "event_id": eventId,
            "event_type": eventType
        ])
    }

    func logEventDeleted(eventId: String, eventType: String) {
        logEvent("event_deleted", parameters: [
            "event_id": eventId,
            "event_type": eventType
        ])
    }

    func logEventShared(eventId: String, method: String) {
        logEvent(AnalyticsEventShare, parameters: [
            AnalyticsParameterContentType: "event",
            AnalyticsParameterItemID: eventId,
            AnalyticsParameterMethod: method
        ])
    }

    // MARK: - Guest Events

    func logGuestAdded(eventId: String, guestCount: Int) {
        logEvent("guest_added", parameters: [
            "event_id": eventId,
            "guest_count": guestCount
        ])
    }

    func logGuestsImported(eventId: String, count: Int) {
        logEvent("guests_imported", parameters: [
            "event_id": eventId,
            "import_count": count
        ])
    }

    func logInvitationSent(eventId: String, guestCount: Int) {
        logEvent("invitation_sent", parameters: [
            "event_id": eventId,
            "guest_count": guestCount
        ])
    }

    func logRsvpReceived(eventId: String, status: String) {
        logEvent("rsvp_received", parameters: [
            "event_id": eventId,
            "rsvp_status": status
        ])
    }

    // MARK: - Task Events

    func logTaskCreated(eventId: String, priority: String) {
        logEvent("task_created", parameters: [
            "event_id": eventId,
            "priority": priority
        ])
    }

    func logTaskCompleted(eventId: String, taskId: String) {
        logEvent("task_completed", parameters: [
            "event_id": eventId,
            "task_id": taskId
        ])
    }

    // MARK: - Expense Events

    func logExpenseAdded(eventId: String, category: String, amount: Double) {
        logEvent("expense_added", parameters: [
            "event_id": eventId,
            "category": category,
            "amount": amount
        ])
    }

    func logBudgetSet(eventId: String, budget: Double) {
        logEvent("budget_set", parameters: [
            "event_id": eventId,
            "budget_amount": budget
        ])
    }

    // MARK: - Agenda Events

    func logAgendaItemAdded(eventId: String) {
        logEvent("agenda_item_added", parameters: [
            "event_id": eventId
        ])
    }

    // MARK: - Subscription Events

    func logSubscriptionStarted(plan: String, price: Double) {
        logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterItemName: plan,
            AnalyticsParameterPrice: price,
            AnalyticsParameterCurrency: "USD"
        ])
    }

    func logSubscriptionCancelled(plan: String) {
        logEvent("subscription_cancelled", parameters: [
            "plan": plan
        ])
    }

    func logPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source
        ])
    }

    func logPaywallView(source: String?) {
        var params: [String: Any] = [:]
        if let source = source {
            params["source"] = source
        }
        logEvent("paywall_view", parameters: params.isEmpty ? nil : params)
    }

    func logPaywallPackageSelected(packageType: String, productId: String) {
        logEvent("paywall_package_selected", parameters: [
            "package_type": packageType,
            "product_id": productId
        ])
    }

    func logTrialStart(packageType: String, productId: String) {
        logEvent("trial_start", parameters: [
            "package_type": packageType,
            "product_id": productId
        ])
    }

    func logSubscriptionPurchase(packageType: String, productId: String, price: Decimal, currency: String) {
        logEvent("subscription_purchase", parameters: [
            "package_type": packageType,
            "product_id": productId,
            "price": NSDecimalNumber(decimal: price).doubleValue,
            "currency": currency
        ])
    }

    // MARK: - Onboarding Events

    func logOnboardingStarted() {
        logEvent("onboarding_started")
    }

    func logOnboardingCompleted() {
        logEvent("onboarding_completed")
    }

    func logOnboardingStepCompleted(step: Int, stepName: String) {
        logEvent("onboarding_step_completed", parameters: [
            "step_number": step,
            "step_name": stepName
        ])
    }

    // MARK: - Engagement Events

    func logAppOpened() {
        logEvent(AnalyticsEventAppOpen)
    }

    func logFeatureUsed(feature: String) {
        logEvent("feature_used", parameters: [
            "feature_name": feature
        ])
    }

    func logSearchPerformed(query: String, resultsCount: Int) {
        logEvent(AnalyticsEventSearch, parameters: [
            AnalyticsParameterSearchTerm: query,
            "results_count": resultsCount
        ])
    }

    // MARK: - Error Events

    func logError(errorCode: String, errorMessage: String, screen: String? = nil) {
        var params: [String: Any] = [
            "error_code": errorCode,
            "error_message": errorMessage
        ]
        if let screen = screen {
            params["screen"] = screen
        }
        logEvent("app_error", parameters: params)
    }
}

// MARK: - Convenience Extension
extension AnalyticsService {
    enum EventType: String {
        case birthday
        case wedding
        case corporate
        case babyShower = "baby_shower"
        case graduation
        case anniversary
        case holiday
        case conference
        case vacation
        case custom
    }

    enum AuthMethod: String {
        case email
        case apple
        case google
    }

    enum ShareMethod: String {
        case link
        case qrCode = "qr_code"
        case contacts
    }
}
