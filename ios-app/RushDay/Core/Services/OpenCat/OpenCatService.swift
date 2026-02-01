import Foundation
import StoreKit

// MARK: - OpenCat Service Implementation

/// Production subscription service powered by OpenCat SDK.
/// Replaces RevenueCat entirely — uses StoreKit 2 for purchases and
/// the OpenCat server for receipt validation, entitlement management, and subscriber tracking.
final class OpenCatServiceImpl: SubscriptionServiceProtocol {

    // MARK: - Configuration

    /// OpenCat server URL (localhost for dev, production URL for release)
    private static let serverUrl = "http://localhost:8080"


    /// Product IDs configured in App Store Connect
    private static let productIds = [
        "com.rushday.premium.annual",
        "com.rushday.premium.monthly"
    ]

    /// OpenCat entitlement identifier
    private static let proEntitlementId = "pro"

    // MARK: - Properties

    private var statusContinuation: AsyncStream<SubscriptionStatus>.Continuation?
    private(set) var isConfigured = false
    private var apiKey: String?
    private var userId: String?

    // MARK: - Subscription Status Publisher

    lazy var subscriptionStatusPublisher: AsyncStream<SubscriptionStatus> = {
        AsyncStream { continuation in
            self.statusContinuation = continuation
            continuation.onTermination = { _ in
                self.statusContinuation = nil
            }
        }
    }()

    // MARK: - Configuration

    func configure(apiKey: String, userId: String?) async throws {
        guard !isConfigured else { return }

        self.apiKey = apiKey
        self.userId = userId

        // Configure OpenCat SDK with server mode
        let appUserId = userId ?? UUID().uuidString
        OpenCat.configureWithServer(
            serverUrl: Self.serverUrl,
            apiKey: apiKey,
            appUserId: appUserId
        )

        #if DEBUG
        OpenCat.setLogLevel(.debug)
        #else
        OpenCat.setLogLevel(.warn)
        #endif

        isConfigured = true

        // Listen for customer info updates
        OpenCat.onCustomerInfoUpdate { [weak self] info in
            guard let self = self else { return }
            let status = self.mapCustomerInfoToStatus(info)
            self.statusContinuation?.yield(status)
        }

        // Fetch initial status
        let status = try await getSubscriptionStatus()
        statusContinuation?.yield(status)
    }

    func ensureConfigured() async {
        guard !isConfigured else { return }

        // Auto-configure with default settings for when AppDelegate has already set up OpenCat
        isConfigured = true

        OpenCat.onCustomerInfoUpdate { [weak self] info in
            guard let self = self else { return }
            let status = self.mapCustomerInfoToStatus(info)
            self.statusContinuation?.yield(status)
        }

        if let status = try? await getSubscriptionStatus() {
            statusContinuation?.yield(status)
        }
    }

    // MARK: - Login

    func login(userId: String, email: String?, displayName: String?) async throws {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        // Re-configure OpenCat with the authenticated user ID
        self.userId = userId
        OpenCat.configureWithServer(
            serverUrl: Self.serverUrl,
            apiKey: apiKey ?? "",
            appUserId: userId
        )

        let status = try await getSubscriptionStatus()
        statusContinuation?.yield(status)
    }

    // MARK: - Logout

    func logout() async throws {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        // Re-configure with anonymous user
        let anonymousId = UUID().uuidString
        self.userId = anonymousId
        OpenCat.configureWithServer(
            serverUrl: Self.serverUrl,
            apiKey: apiKey ?? "",
            appUserId: anonymousId
        )

        statusContinuation?.yield(.inactive)
    }

    // MARK: - Get Offerings

    func getOfferings() async throws -> [SubscriptionPackage] {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        do {
            let offerings = try await OpenCat.getOfferings(productIds: Self.productIds)

            return offerings
                .map { offering in
                    SubscriptionPackage(
                        offering: offering,
                        packageType: SubscriptionPackageType.from(period: offering.subscriptionPeriod)
                    )
                }
                .sorted { lhs, rhs in
                    packageOrder(lhs.packageType) < packageOrder(rhs.packageType)
                }
        } catch let error as OpenCatError {
            throw mapOpenCatError(error)
        }
    }

    // MARK: - Purchase

    func purchase(package: SubscriptionPackage) async throws -> SubscriptionStatus {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        do {
            let transaction = try await OpenCat.purchase(package.offering.storeProductId)

            let status = SubscriptionStatus(
                isActive: transaction.status == .active,
                expirationDate: transaction.expirationDate,
                productId: transaction.productId,
                packageType: package.packageType
            )

            statusContinuation?.yield(status)
            return status
        } catch let error as OpenCatError {
            throw mapOpenCatError(error)
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws -> SubscriptionStatus {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        do {
            let customerInfo = try await OpenCat.restorePurchases()
            let status = mapCustomerInfoToStatus(customerInfo)

            if !status.isActive {
                throw SubscriptionError.noActiveSubscription
            }

            statusContinuation?.yield(status)
            return status
        } catch let error as SubscriptionError {
            throw error
        } catch let error as OpenCatError {
            throw mapOpenCatError(error)
        }
    }

    // MARK: - Get Subscription Status

    func getSubscriptionStatus() async throws -> SubscriptionStatus {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        // First check the synchronous cache
        if OpenCat.isEntitled(Self.proEntitlementId) {
            return SubscriptionStatus(
                isActive: true,
                expirationDate: nil,
                productId: nil,
                packageType: nil
            )
        }

        // Then fetch fresh from server/StoreKit
        do {
            let customerInfo = try await OpenCat.getCustomerInfo()
            return mapCustomerInfoToStatus(customerInfo)
        } catch {
            return .inactive
        }
    }

    // MARK: - Helpers

    private func mapCustomerInfoToStatus(_ info: CustomerInfo) -> SubscriptionStatus {
        // Check for any active entitlement
        for (_, entitlement) in info.activeEntitlements {
            if entitlement.isActive {
                return SubscriptionStatus(
                    isActive: true,
                    expirationDate: entitlement.expirationDate,
                    productId: entitlement.productId,
                    packageType: nil
                )
            }
        }
        return .inactive
    }

    private func mapOpenCatError(_ error: OpenCatError) -> SubscriptionError {
        switch error {
        case .notConfigured:
            return .notConfigured
        case .purchaseCancelled:
            return .purchaseCancelled
        case .purchaseFailed(let msg):
            return .purchaseFailed(msg)
        case .networkError(let msg):
            return .unknownError(msg)
        case .storeError(let msg):
            return .purchaseFailed(msg)
        }
    }

    private func packageOrder(_ type: SubscriptionPackageType) -> Int {
        switch type {
        case .annual: return 0
        case .monthly: return 1
        case .weekly: return 2
        case .lifetime: return 3
        case .unknown: return 99
        }
    }

}
