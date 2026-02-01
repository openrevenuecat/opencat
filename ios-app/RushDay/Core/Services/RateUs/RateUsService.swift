import Foundation
import StoreKit
import UIKit

/// Service to manage Rate Us prompts and conditions
@MainActor
final class RateUsService: ObservableObject {
    static let shared = RateUsService()

    private let storage = RateUsStorage.shared

    // MARK: - Configuration
    private let minTaskCount = 5
    private let minGuestCount = 5

    /// Whether to show the rate us alert (bind from any view)
    @Published var showRateUs = false
    private var hasCheckedThisSession = false

    private init() {}

    // MARK: - Condition Checking

    /// Check global conditions and set `showRateUs` if met. Only runs once per session.
    func checkAndShowIfNeeded(
        events: [Event],
        currentUserId: String,
        taskRepository: TaskRepositoryProtocol,
        guestRepository: GuestRepositoryProtocol,
        expenseRepository: ExpenseRepositoryProtocol
    ) async {
        guard !hasCheckedThisSession else { return }
        hasCheckedThisSession = true

        var hasUpcomingOwnedEvent = false
        var totalTaskCount = 0
        var totalGuestCount = 0
        var hasBudget = false

        #if DEBUG
        print("[RateUs] Aggregating across \(events.count) events for userId: \(currentUserId)")
        #endif

        for event in events {
            let isOwner = currentUserId == event.ownerId
            let isAcceptedCoHost = event.shared.contains { $0.userId == currentUserId && $0.accepted }
            #if DEBUG
            if !isOwner && !isAcceptedCoHost {
                print("[RateUs] Skipping event '\(event.name)' - ownerId: \(event.ownerId), not owner or co-host")
            }
            #endif
            guard isOwner || isAcceptedCoHost else { continue }

            if event.isUpcoming {
                hasUpcomingOwnedEvent = true
            }

            do {
                let tasks = try await taskRepository.getTasksForEvent(eventId: event.id)
                totalTaskCount += tasks.count

                let guests = try await guestRepository.getGuestsForEvent(eventId: event.id)
                totalGuestCount += guests.filter { $0.rsvpStatus == .pending || $0.rsvpStatus == .confirmed }.count

                if !hasBudget {
                    let expenses = try await expenseRepository.getExpensesForEvent(eventId: event.id)
                    hasBudget = expenses.reduce(0) { $0 + $1.amount } > 0
                }
            } catch {
                continue
            }
        }

        let shouldShow = shouldShowRateUs(
            hasUpcomingOwnedEvent: hasUpcomingOwnedEvent,
            totalTaskCount: totalTaskCount,
            totalGuestCount: totalGuestCount,
            hasBudget: hasBudget
        )

        if shouldShow {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showRateUs = true
        }
    }

    /// Check if all conditions are met to show the rate us prompt (global aggregation across all events)
    /// - Parameters:
    ///   - hasUpcomingOwnedEvent: Whether user owns or co-hosts at least one upcoming event
    ///   - totalTaskCount: Total tasks across all user's events
    ///   - totalGuestCount: Total guests (pending/confirmed) across all user's events
    ///   - hasBudget: Whether any event has expenses > 0
    /// - Returns: True if should show rate us prompt
    func shouldShowRateUs(
        hasUpcomingOwnedEvent: Bool,
        totalTaskCount: Int,
        totalGuestCount: Int,
        hasBudget: Bool
    ) -> Bool {
        #if DEBUG
        print("[RateUs] Checking global conditions")
        print("[RateUs] - hasUpcomingOwnedEvent: \(hasUpcomingOwnedEvent)")
        print("[RateUs] - hasBudget: \(hasBudget)")
        print("[RateUs] - totalTaskCount: \(totalTaskCount) (need \(minTaskCount))")
        print("[RateUs] - totalGuestCount: \(totalGuestCount) (need \(minGuestCount))")
        print("[RateUs] - hasRatedApp: \(storage.hasRatedApp)")
        print("[RateUs] - hasExceededMaxReminders: \(storage.hasExceededMaxReminders)")
        print("[RateUs] - isReminderDue: \(storage.isReminderDue)")
        #endif

        // 1. User must own or co-host at least one upcoming event
        guard hasUpcomingOwnedEvent else {
            #if DEBUG
            print("[RateUs] ❌ Failed: no upcoming owned/co-hosted event")
            #endif
            return false
        }

        // 2. Must have budget in at least one event
        guard hasBudget else {
            #if DEBUG
            print("[RateUs] ❌ Failed: no budget in any event")
            #endif
            return false
        }

        // 3. Must have at least 5 tasks globally
        guard totalTaskCount >= minTaskCount else {
            #if DEBUG
            print("[RateUs] ❌ Failed: not enough tasks (\(totalTaskCount)/\(minTaskCount))")
            #endif
            return false
        }

        // 4. Must have at least 5 guests globally
        guard totalGuestCount >= minGuestCount else {
            #if DEBUG
            print("[RateUs] ❌ Failed: not enough guests (\(totalGuestCount)/\(minGuestCount))")
            #endif
            return false
        }

        // 5. User hasn't already rated the app
        guard !storage.hasRatedApp else {
            #if DEBUG
            print("[RateUs] ❌ Failed: already rated app")
            #endif
            return false
        }

        // 6. Check reminder logic
        if storage.hasExceededMaxReminders {
            #if DEBUG
            print("[RateUs] ❌ Failed: exceeded max reminders")
            #endif
            return false
        }

        if !storage.isReminderDue {
            #if DEBUG
            print("[RateUs] ❌ Failed: reminder not due yet")
            #endif
            return false
        }

        #if DEBUG
        print("[RateUs] ✅ All conditions passed!")
        #endif
        return true
    }

    // MARK: - Actions

    /// User chose "Love it" - open App Store rating
    func handleLoveIt() {
        storage.hasRatedApp = true
        requestAppStoreReview()
    }

    /// User chose "Not really" - will navigate to feedback form
    func handleNotReally() {
        storage.hasRatedApp = true
    }

    /// User chose "Ask me later"
    func handleAskLater() {
        storage.scheduleNextReminder()
    }

    // MARK: - App Store Review

    private func requestAppStoreReview() {
        // Use StoreKit to request review
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        SKStoreReviewController.requestReview(in: windowScene)
    }

    // MARK: - Debug

    /// Reset rate us state (for testing)
    func resetForTesting() {
        storage.reset()
        hasCheckedThisSession = false
        showRateUs = false
    }
}

// MARK: - Rate Us Storage

/// Storage for Rate Us feature persistence
final class RateUsStorage {
    static let shared = RateUsStorage()

    private let userDefaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let hasRated = "rate_us_has_rated"
        static let nextReminderDate = "rate_us_next_reminder_date"
        static let reminderCount = "rate_us_reminder_count"
    }

    // MARK: - Constants
    private let maxReminders = 3
    private let reminderIntervalDays = 7

    private init() {}

    // MARK: - Has Rated (Global)

    /// Whether the user has ever rated the app
    var hasRatedApp: Bool {
        get { userDefaults.bool(forKey: Keys.hasRated) }
        set { userDefaults.set(newValue, forKey: Keys.hasRated) }
    }

    // MARK: - Reminder Management

    /// The next date when we should show the rating prompt
    var nextReminderDate: Date? {
        get { userDefaults.object(forKey: Keys.nextReminderDate) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.nextReminderDate) }
    }

    /// How many times user has clicked "Ask me later"
    var reminderCount: Int {
        get { userDefaults.integer(forKey: Keys.reminderCount) }
        set { userDefaults.set(newValue, forKey: Keys.reminderCount) }
    }

    /// Whether we've exceeded max reminders
    var hasExceededMaxReminders: Bool {
        reminderCount >= maxReminders
    }

    /// Schedule next reminder (add 7 days)
    func scheduleNextReminder() {
        reminderCount += 1
        nextReminderDate = Calendar.current.date(byAdding: .day, value: reminderIntervalDays, to: Date())
    }

    /// Check if it's time to show reminder based on scheduled date
    var isReminderDue: Bool {
        guard let nextDate = nextReminderDate else { return true }
        return Date() >= nextDate
    }

    // MARK: - Reset

    /// Reset all rate us storage (for debugging)
    func reset() {
        userDefaults.removeObject(forKey: Keys.hasRated)
        userDefaults.removeObject(forKey: Keys.nextReminderDate)
        userDefaults.removeObject(forKey: Keys.reminderCount)
    }
}
