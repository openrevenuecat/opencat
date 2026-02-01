import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

// MARK: - FCM Notification Service Implementation
class FCMNotificationServiceImpl: NSObject, NotificationServiceProtocol {
    private let messaging = Messaging.messaging()
    private let notificationCenter = UNUserNotificationCenter.current()

    // Token storage key
    private let fcmTokenKey = "fcm_token"

    override init() {
        super.init()
        messaging.delegate = self
    }

    // MARK: - Token Storage

    /// Returns the cached FCM token from UserDefaults
    var cachedToken: String? {
        UserDefaults.standard.string(forKey: fcmTokenKey)
    }

    /// Stores the FCM token in UserDefaults
    private func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: fcmTokenKey)
    }

    /// Clears the stored FCM token
    func clearStoredToken() {
        UserDefaults.standard.removeObject(forKey: fcmTokenKey)
    }

    // MARK: - Register for Push Notifications

    func registerForPushNotifications() async throws -> String? {
        // Request authorization
        let granted = try await requestAuthorization()

        guard granted else {
            return nil
        }

        // Register for remote notifications on main thread
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // Wait for APNS token to be set before getting FCM token
        // The APNS token arrives async via AppDelegate callback
        try await waitForAPNSToken()

        // Get FCM token
        return try await getFCMToken()
    }

    // MARK: - Wait for APNS Token

    /// Waits for the APNS token to be set on Firebase Messaging
    /// This is necessary because registerForRemoteNotifications() is async
    /// and the APNS token arrives via AppDelegate callback
    private func waitForAPNSToken(maxAttempts: Int = 10, delayMs: UInt64 = 500) async throws {
        for _ in 1...maxAttempts {
            // Check if APNS token is already set
            if messaging.apnsToken != nil {
                return
            }

            // Wait before checking again
            try await Task.sleep(nanoseconds: delayMs * 1_000_000)
        }

        // If still no token after all attempts, throw error
        throw NotificationError.apnsTokenNotReceived
    }

    // MARK: - Request Authorization

    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return try await notificationCenter.requestAuthorization(options: options)
    }

    // MARK: - Get FCM Token

    func getFCMToken() async throws -> String {
        let token = try await messaging.token()
        storeToken(token)
        return token
    }

    /// Returns the cached token or fetches a new one
    func getToken() async -> String? {
        // Try cached token first
        if let cached = cachedToken {
            return cached
        }

        // Fetch new token
        do {
            return try await getFCMToken()
        } catch {
            return nil
        }
    }

    // MARK: - Subscribe to Topic

    func subscribeToTopic(_ topic: String) async throws {
        try await messaging.subscribe(toTopic: topic)
    }

    // MARK: - Unsubscribe from Topic

    func unsubscribeFromTopic(_ topic: String) async throws {
        try await messaging.unsubscribe(fromTopic: topic)
    }

    // MARK: - Schedule Local Notification

    func scheduleLocalNotification(title: String, body: String, date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await notificationCenter.add(request)
    }

    // MARK: - Schedule Notification with ID

    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        userInfo: [String: Any]? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let userInfo = userInfo {
            content.userInfo = userInfo
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await notificationCenter.add(request)
    }

    // MARK: - Cancel Notification

    func cancelNotification(id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Cancel All Notifications

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Get Pending Notifications

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }

    // MARK: - Check Notification Status

    func getNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Badge Management

    func setBadgeCount(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            // Error handled silently
        }
    }

    func clearBadge() async {
        await setBadgeCount(0)
    }
}

// MARK: - Messaging Delegate
extension FCMNotificationServiceImpl: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        // Store the new token
        storeToken(token)

        // Post notification for token refresh
        NotificationCenter.default.post(
            name: Notification.Name("FCMTokenRefreshed"),
            object: nil,
            userInfo: ["token": token]
        )
    }
}

// MARK: - Notification Error
enum NotificationError: LocalizedError {
    case notAuthorized
    case tokenNotFound
    case schedulingFailed
    case apnsTokenNotReceived
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Push notifications not authorized"
        case .tokenNotFound:
            return "FCM token not found"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .apnsTokenNotReceived:
            return "APNS token not received - check provisioning profile has Push Notifications capability"
        case .unknown(let message):
            return message
        }
    }
}
