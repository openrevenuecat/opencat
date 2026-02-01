import Foundation
import SwiftUI

@MainActor
class EditEventViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var eventName: String
    @Published var startDate: Date
    @Published var endDate: Date?
    @Published var venue: String
    @Published var customIdea: String
    @Published var isAllDay: Bool
    @Published var isLoading = false
    @Published var error: String?
    @Published var showDeleteConfirmation = false
    @Published var showDiscardAlert = false

    // MARK: - Private Properties
    private let originalEvent: Event
    private let eventRepository: EventRepositoryProtocol

    // MARK: - Computed Properties
    var hasChanges: Bool {
        eventName != originalEvent.name ||
        startDate != originalEvent.startDate ||
        endDate != originalEvent.endDate ||
        (venue.isEmpty ? nil : venue) != originalEvent.venue ||
        (customIdea.isEmpty ? nil : customIdea) != originalEvent.customIdea ||
        isAllDay != originalEvent.isAllDay
    }

    var isValidEventName: Bool {
        eventName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var canSave: Bool {
        hasChanges && isValidEventName
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()

        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            if let endDate = endDate {
                let startDateString = formatter.string(from: startDate)
                let endDateString = formatter.string(from: endDate)
                if startDateString == endDateString {
                    return startDateString
                }
                return "\(startDateString) - \(endDateString)"
            } else {
                return formatter.string(from: startDate)
            }
        } else {
            formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
            let startDateString = formatter.string(from: startDate)

            if let endDate = endDate {
                let calendar = Calendar.current
                let sameDay = calendar.isDate(startDate, inSameDayAs: endDate)

                if sameDay {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "h:mm a"
                    return "\(startDateString) - \(timeFormatter.string(from: endDate))"
                } else {
                    return "\(startDateString) - \(formatter.string(from: endDate))"
                }
            } else {
                return startDateString
            }
        }
    }

    // MARK: - Initialization
    init(event: Event, eventRepository: EventRepositoryProtocol = DIContainer.shared.eventRepository) {
        self.originalEvent = event
        self.eventRepository = eventRepository

        // Initialize with original event values
        self.eventName = event.name
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.venue = event.venue ?? ""
        self.customIdea = event.customIdea ?? ""
        self.isAllDay = event.isAllDay
    }

    // MARK: - Actions
    func updateDateTime(startDate: Date, endDate: Date?, isAllDay: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }

    func saveEvent() -> Event {
        var updatedEvent = originalEvent
        updatedEvent.name = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.startDate = startDate
        updatedEvent.endDate = endDate
        updatedEvent.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : venue.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.customIdea = customIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.isAllDay = isAllDay
        updatedEvent.updatedAt = Date()
        return updatedEvent
    }

    func saveEventToRepository() async -> Event? {
        guard canSave else { return nil }

        isLoading = true
        defer { isLoading = false }

        let updatedEvent = saveEvent()

        do {
            try await eventRepository.updateEvent(updatedEvent)
            return updatedEvent
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteEvent() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await eventRepository.deleteEvent(id: originalEvent.id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func resetChanges() {
        eventName = originalEvent.name
        startDate = originalEvent.startDate
        endDate = originalEvent.endDate
        venue = originalEvent.venue ?? ""
        customIdea = originalEvent.customIdea ?? ""
        isAllDay = originalEvent.isAllDay
    }
}
