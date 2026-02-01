import Foundation
import FirebaseFirestore

// MARK: - User Notification Names
extension Notification.Name {
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
}

// MARK: - User Entity (matches Flutter Firestore structure)
/// Firestore collection: "users"
/// Field names match Flutter's user_model.dart for cross-platform compatibility
struct User: Identifiable, Codable, Hashable {
    let id: String
    var name: String                           // Flutter: name
    var email: String                          // Flutter: email
    var photoUrl: String?                      // Flutter: photoUrl
    var currency: String                       // Flutter: currency (default: "USD")
    var isPremium: Bool                        // Flutter: isPremium
    var createAt: Date                         // Flutter: createAt (ISO 8601 string in Firestore)
    var updateAt: Date?                        // Flutter: updateAt (nullable ISO 8601)
    var events: [String]                       // Flutter: events (array of event IDs)
    var notificationConfiguration: NotificationConfiguration?  // Flutter: notificationConfiguration

    // CodingKeys to match exact Firestore field names
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case photoUrl
        case currency
        case isPremium
        case createAt
        case updateAt
        case events
        case notificationConfiguration
    }

    init(
        id: String,
        name: String,
        email: String,
        photoUrl: String? = nil,
        currency: String = "USD",
        isPremium: Bool = false,
        createAt: Date = Date(),
        updateAt: Date? = nil,
        events: [String] = [],
        notificationConfiguration: NotificationConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.photoUrl = photoUrl
        self.currency = currency
        self.isPremium = isPremium
        self.createAt = createAt
        self.updateAt = updateAt
        self.events = events
        self.notificationConfiguration = notificationConfiguration
    }

    // MARK: - Custom Decoding (handles ISO 8601 strings from Flutter)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        events = try container.decodeIfPresent([String].self, forKey: .events) ?? []
        notificationConfiguration = try container.decodeIfPresent(NotificationConfiguration.self, forKey: .notificationConfiguration)

        // Handle createAt - could be ISO 8601 string, Timestamp, or Date
        createAt = Self.decodeDate(from: container, forKey: .createAt) ?? Date()

        // Handle updateAt - could be ISO 8601 string, Timestamp, Date, or nil
        updateAt = Self.decodeDate(from: container, forKey: .updateAt)
    }

    /// Decodes a date field that could be stored as ISO 8601 string, Firestore Timestamp, or Date
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try decoding as Date first (handles Firestore Timestamp automatically)
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }

        // Try decoding as ISO 8601 string (Flutter pattern)
        if let dateString = try? container.decode(String.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // Convenience computed property for backward compatibility
    var displayName: String? {
        name.isEmpty ? nil : name
    }

    var photoURL: String? {
        photoUrl
    }

    var initials: String? {
        guard !name.isEmpty else { return nil }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Notification Configuration (matches Flutter structure)
struct NotificationConfiguration: Codable, Hashable {
    var enableAll: Bool
    var isEnableUpComingReminder: Bool
    var isEnableAgendaReminder: Bool
    var isEnableGuestUpdatesReminder: Bool
    var upComingPeriod: UpComingEventReminderPeriod
    var agendaReminderPeriod: AgendaReminderPeriod
    var upComingReminderTime: String  // Format: "HH:mm" (e.g., "9:00")

    init(
        enableAll: Bool = true,
        isEnableUpComingReminder: Bool = true,
        isEnableAgendaReminder: Bool = true,
        isEnableGuestUpdatesReminder: Bool = true,
        upComingPeriod: UpComingEventReminderPeriod = .onEventDay,
        agendaReminderPeriod: AgendaReminderPeriod = .atActivityTime,
        upComingReminderTime: String = "9:00"
    ) {
        self.enableAll = enableAll
        self.isEnableUpComingReminder = isEnableUpComingReminder
        self.isEnableAgendaReminder = isEnableAgendaReminder
        self.isEnableGuestUpdatesReminder = isEnableGuestUpdatesReminder
        self.upComingPeriod = upComingPeriod
        self.agendaReminderPeriod = agendaReminderPeriod
        self.upComingReminderTime = upComingReminderTime
    }

    /// Creates NotificationConfiguration from gRPC NotificationPreferences
    init(from grpcPrefs: Rushday_V1_NotificationPreferences) {
        // Map time (default to "9:00" if empty)
        self.upComingReminderTime = grpcPrefs.time.isEmpty ? "9:00" : grpcPrefs.time

        // Map boolean flags
        self.isEnableUpComingReminder = grpcPrefs.tasks
        self.isEnableAgendaReminder = grpcPrefs.agenda
        self.isEnableGuestUpdatesReminder = grpcPrefs.share

        // Derive upComingPeriod from on_the_day and week_before flags
        if grpcPrefs.weekBefore {
            self.upComingPeriod = .weekBefore
        } else if grpcPrefs.onTheDay {
            self.upComingPeriod = .onEventDay
        } else {
            self.upComingPeriod = .onEventDay  // Default
        }

        // agendaReminderPeriod is not stored in gRPC, use default
        self.agendaReminderPeriod = .atActivityTime

        // Derive enableAll: true if any notification is enabled
        self.enableAll = grpcPrefs.tasks || grpcPrefs.agenda || grpcPrefs.share
    }
}

// MARK: - Upcoming Event Reminder Period
enum UpComingEventReminderPeriod: String, Codable, CaseIterable, Equatable, Hashable {
    case onEventDay = "on_event_day"
    case dayBefore = "day_before"
    case weekBefore = "week_before"
    case twoWeeksBefore = "two_weeks_before"
    case monthBefore = "month_before"

    var displayName: String {
        switch self {
        case .onEventDay: return "On Event Day"
        case .dayBefore: return "1 Day Before Event"
        case .weekBefore: return "1 Week Before Event"
        case .twoWeeksBefore: return "2 Weeks Before Event"
        case .monthBefore: return "1 Month Before Event"
        }
    }
}

// MARK: - Agenda Reminder Period
enum AgendaReminderPeriod: String, Codable, CaseIterable, Equatable, Hashable {
    case atActivityTime = "at_time"
    case fiveMinutesBefore = "5_minutes_before"
    case fifteenMinutesBefore = "15_minutes_before"
    case thirtyMinutesBefore = "30_minutes_before"

    var displayName: String {
        switch self {
        case .atActivityTime: return "At Activity Time"
        case .fiveMinutesBefore: return "5 min before"
        case .fifteenMinutesBefore: return "15 min before"
        case .thirtyMinutesBefore: return "30 min before"
        }
    }
}

// MARK: - Mock Data
extension User {
    static let mock = User(
        id: "user_123",
        name: "John Doe",
        email: "john@example.com",
        isPremium: true,
        events: ["event_123", "event_456"]
    )
}
