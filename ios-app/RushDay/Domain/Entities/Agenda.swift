import Foundation

struct AgendaItem: Identifiable, Codable, Hashable {
    let id: String
    var eventId: String?  // Optional - may not be stored in subcollection documents
    var title: String
    var description: String?
    var startTime: Date
    var endTime: Date?
    var location: String?
    var speakerId: String?
    var speakerName: String?
    var isBreak: Bool
    var order: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String? = nil,
        title: String,
        description: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        location: String? = nil,
        speakerId: String? = nil,
        speakerName: String? = nil,
        isBreak: Bool = false,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.speakerId = speakerId
        self.speakerName = speakerName
        self.isBreak = isBreak
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var durationText: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension AgendaItem {
    static let mock = AgendaItem(
        id: "agenda_123",
        eventId: "event_123",
        title: "Welcome & Check-in",
        description: "Guests arrive and check in at the venue",
        startTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!,
        endTime: Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!,
        order: 1
    )

    static let mockList: [AgendaItem] = [
        .mock,
        AgendaItem(
            id: "agenda_456",
            eventId: "event_123",
            title: "Cocktail Hour",
            startTime: Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!,
            location: "Garden Area",
            order: 2
        ),
        AgendaItem(
            id: "agenda_789",
            eventId: "event_123",
            title: "Dinner",
            startTime: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!,
            location: "Main Hall",
            order: 3
        ),
        AgendaItem(
            id: "agenda_break",
            eventId: "event_123",
            title: "Break",
            startTime: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 21, minute: 15, second: 0, of: Date())!,
            isBreak: true,
            order: 4
        ),
        AgendaItem(
            id: "agenda_012",
            eventId: "event_123",
            title: "Cake & Celebration",
            startTime: Calendar.current.date(bySettingHour: 21, minute: 15, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!,
            order: 5
        )
    ]
}
