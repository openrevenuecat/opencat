import Foundation

// MARK: - Subscription Status
struct SubscriptionStatus {
    let isActive: Bool
    let expirationDate: Date?
    let productId: String?
    let packageType: SubscriptionPackageType?

    static let inactive = SubscriptionStatus(
        isActive: false,
        expirationDate: nil,
        productId: nil,
        packageType: nil
    )
}

// MARK: - Subscription Error
enum SubscriptionError: LocalizedError {
    case notConfigured
    case purchaseCancelled
    case purchaseFailed(String)
    case noActiveSubscription
    case restoreFailed(String)
    case networkError
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscription service is not configured"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .noActiveSubscription:
            return "No active subscription found"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .networkError:
            return "Network error occurred"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// Keep old name as typealias for backward compatibility during migration
typealias RevenueCatError = SubscriptionError
typealias RevenueCatServiceProtocol = SubscriptionServiceProtocol

// MARK: - Subscription Service Protocol
protocol SubscriptionServiceProtocol {
    var subscriptionStatusPublisher: AsyncStream<SubscriptionStatus> { get }
    var isConfigured: Bool { get }

    func configure(apiKey: String, userId: String?) async throws
    func ensureConfigured() async
    func login(userId: String, email: String?, displayName: String?) async throws
    func logout() async throws
    func getOfferings() async throws -> [SubscriptionPackage]
    func purchase(package: SubscriptionPackage) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
    func getSubscriptionStatus() async throws -> SubscriptionStatus
}

// MARK: - Mock Implementation for Preview/Testing
#if DEBUG
final class MockSubscriptionService: SubscriptionServiceProtocol {
    var subscriptionStatusPublisher: AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in
            continuation.yield(.inactive)
        }
    }

    var isConfigured: Bool = true

    func configure(apiKey: String, userId: String?) async throws {}
    func ensureConfigured() async {}
    func login(userId: String, email: String?, displayName: String?) async throws {}
    func logout() async throws {}

    func getOfferings() async throws -> [SubscriptionPackage] {
        return []
    }

    func purchase(package: SubscriptionPackage) async throws -> SubscriptionStatus {
        return SubscriptionStatus(
            isActive: true,
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
            productId: "com.rushday.premium.annual",
            packageType: .annual
        )
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        throw SubscriptionError.noActiveSubscription
    }

    func getSubscriptionStatus() async throws -> SubscriptionStatus {
        return .inactive
    }
}
#endif
