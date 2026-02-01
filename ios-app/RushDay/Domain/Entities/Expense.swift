import Foundation
import SwiftUI

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case venue = "venue"
    case catering = "catering"
    case decoration = "decoration"
    case entertainment = "entertainment"
    case photography = "photography"
    case transportation = "transportation"
    case attire = "attire"
    case gifts = "gifts"
    case accommodation = "accommodation"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .venue: return "Venue"
        case .catering: return "Catering"
        case .decoration: return "Decoration"
        case .entertainment: return "Entertainment"
        case .photography: return "Photography"
        case .transportation: return "Transportation"
        case .attire: return "Attire"
        case .gifts: return "Gifts"
        case .accommodation: return "Accommodation"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .venue: return "building.2"
        case .catering: return "fork.knife"
        case .decoration: return "sparkles"
        case .entertainment: return "music.note"
        case .photography: return "camera"
        case .transportation: return "car"
        case .attire: return "tshirt"
        case .gifts: return "gift"
        case .accommodation: return "bed.double"
        case .other: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .venue: return Color(hex: "6366F1")
        case .catering: return Color(hex: "EC4899")
        case .decoration: return Color(hex: "F59E0B")
        case .entertainment: return Color(hex: "8B5CF6")
        case .photography: return Color(hex: "10B981")
        case .transportation: return Color(hex: "3B82F6")
        case .attire: return Color(hex: "F97316")
        case .gifts: return Color(hex: "EF4444")
        case .accommodation: return Color(hex: "06B6D4")
        case .other: return Color(hex: "6B7280")
        }
    }
}

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case partial = "partial"
    case paid = "paid"
    case refunded = "refunded"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .partial: return "Partial"
        case .paid: return "Paid"
        case .refunded: return "Refunded"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .rdWarning
        case .partial: return .rdAccent
        case .paid: return .rdSuccess
        case .refunded: return .rdTextSecondary
        }
    }
}

struct Expense: Identifiable, Codable, Hashable {
    let id: String
    var eventId: String?  // Optional - may not be stored in subcollection documents
    var title: String
    var description: String?
    var category: ExpenseCategory
    var amount: Double
    var paidAmount: Double
    var currency: String
    var paymentStatus: PaymentStatus
    var vendorId: String?
    var vendorName: String?
    var dueDate: Date?
    var paidDate: Date?
    var receiptURL: String?
    var notes: String?
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String? = nil,
        title: String,
        description: String? = nil,
        category: ExpenseCategory,
        amount: Double,
        paidAmount: Double = 0,
        currency: String = "USD",
        paymentStatus: PaymentStatus = .pending,
        vendorId: String? = nil,
        vendorName: String? = nil,
        dueDate: Date? = nil,
        paidDate: Date? = nil,
        receiptURL: String? = nil,
        notes: String? = nil,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.description = description
        self.category = category
        self.amount = amount
        self.paidAmount = paidAmount
        self.currency = currency
        self.paymentStatus = paymentStatus
        self.vendorId = vendorId
        self.vendorName = vendorName
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.receiptURL = receiptURL
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var remainingAmount: Double {
        amount - paidAmount
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

extension Expense {
    static let mock = Expense(
        id: "expense_123",
        eventId: "event_123",
        title: "Venue Rental",
        description: "Main hall rental for 6 hours",
        category: .venue,
        amount: 2500,
        paidAmount: 1000,
        paymentStatus: .partial,
        vendorName: "Grand Ballroom",
        createdBy: "user_123"
    )

    static let mockList: [Expense] = [
        .mock,
        Expense(
            id: "expense_456",
            eventId: "event_123",
            title: "Catering Service",
            category: .catering,
            amount: 1500,
            paymentStatus: .pending,
            vendorName: "Delicious Bites",
            createdBy: "user_123"
        ),
        Expense(
            id: "expense_789",
            eventId: "event_123",
            title: "Photographer",
            category: .photography,
            amount: 800,
            paidAmount: 800,
            paymentStatus: .paid,
            vendorName: "Pro Shots",
            createdBy: "user_123"
        ),
        Expense(
            id: "expense_012",
            eventId: "event_123",
            title: "Balloons & Banners",
            category: .decoration,
            amount: 200,
            paymentStatus: .pending,
            createdBy: "user_123"
        )
    ]
}
