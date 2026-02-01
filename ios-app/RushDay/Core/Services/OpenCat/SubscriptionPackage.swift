import Foundation
import StoreKit

// MARK: - Subscription Package

/// A wrapper around `ProductOffering` (from server) that provides the display interface
/// needed by Paywall screens.
struct SubscriptionPackage: Identifiable {
    let offering: ProductOffering
    let packageType: SubscriptionPackageType

    var id: String { offering.storeProductId }
    var identifier: String { offering.storeProductId }

    // MARK: - Store Product Interface

    var storeProduct: StoreProductInfo { StoreProductInfo(offering: offering) }

    // MARK: - Free Trial

    var hasFreeTrial: Bool {
        offering.trialPeriod != nil
    }

    var freeTrialDays: Int {
        guard let period = offering.trialPeriod else { return 0 }
        return isoDurationToDays(period)
    }

    // MARK: - Display Helpers

    var displayTitle: String {
        switch packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        case .unknown: return offering.displayName
        }
    }

    var pricePerMonth: String {
        switch packageType {
        case .annual:
            let monthlyPrice = offering.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = offering.currency
            return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? offering.displayPrice
        default:
            return offering.displayPrice
        }
    }

    /// The StoreKit Product for purchasing (nil if StoreKit unavailable)
    var storeKitProduct: Product? { offering.storeProduct }
}

// MARK: - Package Type

enum SubscriptionPackageType: String {
    case annual = "ANNUAL"
    case monthly = "MONTHLY"
    case weekly = "WEEKLY"
    case lifetime = "LIFETIME"
    case unknown = "UNKNOWN"

    var stringValue: String {
        switch self {
        case .annual: return "annual"
        case .monthly: return "monthly"
        case .weekly: return "weekly"
        case .lifetime: return "lifetime"
        case .unknown: return "unknown"
        }
    }

    /// Infer package type from ISO 8601 subscription period.
    static func from(period: String?) -> SubscriptionPackageType {
        guard let period = period else { return .lifetime }
        switch period {
        case "P1Y": return .annual
        case "P1M": return .monthly
        case "P1W": return .weekly
        default:
            if period.contains("Y") { return .annual }
            if period.contains("M") { return .monthly }
            if period.contains("W") { return .weekly }
            return .unknown
        }
    }

    /// Infer package type from a StoreKit Product (fallback for standalone mode).
    static func from(product: Product) -> SubscriptionPackageType {
        guard let subscription = product.subscription else { return .lifetime }
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .year: return .annual
        case .month:
            if period.value >= 12 { return .annual }
            return .monthly
        case .week: return .weekly
        case .day:
            if period.value >= 28 { return .monthly }
            if period.value >= 7 { return .weekly }
            return .unknown
        @unknown default: return .unknown
        }
    }
}

// MARK: - Store Product Info

/// Provides a unified product info interface regardless of whether data comes from server or StoreKit.
struct StoreProductInfo {
    let offering: ProductOffering

    var price: Decimal { offering.price }
    var localizedTitle: String { offering.displayName }
    var localizedPriceString: String { offering.displayPrice }
    var productIdentifier: String { offering.storeProductId }
    var currencyCode: String? { offering.currency }
    var introductoryDiscount: IntroductoryDiscount? {
        guard offering.trialPeriod != nil else { return nil }
        return IntroductoryDiscount(trialPeriod: offering.trialPeriod!)
    }
}

// MARK: - Introductory Discount

struct IntroductoryDiscount {
    let trialPeriod: String

    var subscriptionPeriod: SubscriptionPeriodInfo {
        SubscriptionPeriodInfo(isoPeriod: trialPeriod)
    }
}

struct SubscriptionPeriodInfo {
    let isoPeriod: String

    var unit: PeriodUnit {
        if isoPeriod.contains("Y") { return .year }
        if isoPeriod.contains("M") { return .month }
        if isoPeriod.contains("W") { return .week }
        return .day
    }

    var value: Int {
        isoDurationToValue(isoPeriod)
    }

    enum PeriodUnit {
        case day, week, month, year
    }
}

// MARK: - ISO 8601 Duration Helpers

private func isoDurationToDays(_ period: String) -> Int {
    let value = isoDurationToValue(period)
    if period.contains("D") { return value }
    if period.contains("W") { return value * 7 }
    if period.contains("M") { return value * 30 }
    if period.contains("Y") { return value * 365 }
    return 0
}

private func isoDurationToValue(_ period: String) -> Int {
    let digits = period.filter { $0.isNumber }
    return Int(digits) ?? 0
}
