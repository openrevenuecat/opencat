import Foundation

// MARK: - User Repository
protocol UserRepositoryProtocol {
    func getCurrentUser() async throws -> User?
    func getUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    func deleteUser(id: String) async throws
    func checkAndSaveUser(_ user: User) async throws -> (user: User, isNew: Bool)
    func saveUser(_ user: User) async throws
    /// Save event ID to user's events array (Flutter pattern: FieldValue.arrayUnion)
    func saveEventId(userId: String, eventId: String) async throws
    /// Remove event ID from user's events array (Flutter pattern: FieldValue.arrayRemove)
    func removeEventId(userId: String, eventId: String) async throws
}

// MARK: - Event Repository
protocol EventRepositoryProtocol {
    func getEvent(id: String) async throws -> Event
    func getEventsForUser(userId: String) async throws -> [Event]
    func getUpcomingEvents(userId: String) async throws -> [Event]
    func getPastEvents(userId: String) async throws -> [Event]
    func createEvent(_ event: Event) async throws -> String
    func updateEvent(_ event: Event) async throws
    func deleteEvent(id: String) async throws
    /// Add user to joinedUser subcollection when creating/joining event
    func addJoinedUser(eventId: String, joinedUser: JoinedUser) async throws -> String
    func getJoinedUsers(eventId: String) async throws -> [JoinedUser]
}

// MARK: - Guest Repository
protocol GuestRepositoryProtocol {
    func getGuest(id: String) async throws -> Guest
    func getGuestsForEvent(eventId: String) async throws -> [Guest]
    func addGuest(_ guest: Guest) async throws -> String
    func updateGuest(_ guest: Guest) async throws
    func removeGuest(id: String, eventId: String) async throws
    func updateRSVP(guestId: String, status: RSVPStatus) async throws
}

// MARK: - Task Repository
protocol TaskRepositoryProtocol {
    func getTask(id: String) async throws -> EventTask
    func getTasksForEvent(eventId: String) async throws -> [EventTask]
    func createTask(_ task: EventTask) async throws -> EventTask
    func updateTask(_ task: EventTask) async throws
    func deleteTask(id: String) async throws
    func updateTaskStatus(taskId: String, status: TaskStatus) async throws
    func reorderTasks(eventId: String, taskIds: [String]) async throws -> [EventTask]
}

// MARK: - Expense Repository
protocol ExpenseRepositoryProtocol {
    func getExpense(id: String) async throws -> Expense
    func getExpensesForEvent(eventId: String) async throws -> [Expense]
    func createExpense(_ expense: Expense) async throws -> String
    func updateExpense(_ expense: Expense) async throws
    func deleteExpense(id: String) async throws
    func getTotalExpenses(eventId: String) async throws -> Double
    /// Add a payment to an expense (marks it as paid)
    func addPayment(expenseId: String, amount: Double) async throws -> Expense
    /// Remove payment from an expense (marks it as unpaid)
    func removePayment(expenseId: String) async throws -> Expense
}

// MARK: - Agenda Repository
protocol AgendaRepositoryProtocol {
    func getAgendaItem(id: String) async throws -> AgendaItem
    func getAgendaForEvent(eventId: String) async throws -> [AgendaItem]
    func createAgendaItem(_ item: AgendaItem) async throws -> String
    func updateAgendaItem(_ item: AgendaItem) async throws
    func deleteAgendaItem(id: String) async throws
    func reorderAgenda(eventId: String, itemIds: [String]) async throws
}

// MARK: - Notification Repository
/// Repository for managing scheduled push notifications via the notification service.
protocol NotificationRepositoryProtocol {
    /// Get the current FCM token
    func getFcmToken() async throws -> String?

    /// Create a single scheduled notification
    func createNotification(_ request: CreateNotificationRequest) async throws -> Bool

    /// Create multiple notifications in batch
    func createNotificationsBatch(_ requests: [CreateNotificationRequest]) async throws -> Bool

    /// Update all notifications in a group
    func updateNotificationsByGroup(
        groupField: GroupField,
        groupValue: String,
        title: String?,
        body: String?,
        sendAt: Date?,
        data: [String: AnyCodable]?
    ) async throws -> Bool

    /// Delete all notifications in a group
    func deleteNotificationsByGroup(
        groupField: GroupField,
        groupValue: String
    ) async throws -> Bool

    /// Delete a specific user's notification from a group
    func deleteUserNotificationFromGroup(
        groupField: GroupField,
        groupValue: String,
        userId: String
    ) async throws -> Bool

    /// Delete multiple notifications by filters
    func deleteNotificationsBatch(_ filters: [[String: String]]) async throws -> Bool

    /// Adjust notification timing by type
    func editNotificationPeriodByType(
        userId: String,
        type: NotificationType,
        deltaMs: Int
    ) async throws -> Bool

    /// Toggle notification type on/off
    func toggleNotificationType(
        userId: String,
        type: NotificationType,
        enabled: Bool
    ) async throws -> Bool
}
