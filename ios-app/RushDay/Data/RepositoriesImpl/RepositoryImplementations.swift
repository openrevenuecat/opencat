import Foundation
import SwiftProtobuf

// MARK: - Firestore Collection Names (matches Flutter constants)
enum FirestoreCollections {
    static let users = "users"
    static let events = "events"
    static let draftEvents = "draftEvents"

    // Subcollections under events
    enum EventSubcollections {
        static let tasks = "tasks"
        static let expenses = "expenses"
        static let agendas = "agendas"
        static let guests = "guests"
        static let joinedUser = "joinedUser"
    }
}

// MARK: - User Repository Implementation (Flutter pattern)
class UserRepositoryImpl: UserRepositoryProtocol {
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol
    private let collection = FirestoreCollections.users

    init(firestoreService: FirestoreServiceProtocol, authService: AuthServiceProtocol) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    func getCurrentUser() async throws -> User? {
        return authService.currentUser
    }

    func getUser(id: String) async throws -> User {
        return try await firestoreService.get(collection: collection, documentId: id)
    }

    func updateUser(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updateAt = Date()
        try await firestoreService.update(collection: collection, documentId: user.id, data: updatedUser)
    }

    func deleteUser(id: String) async throws {
        try await firestoreService.delete(collection: collection, documentId: id)
    }

    func checkAndSaveUser(_ user: User) async throws -> (user: User, isNew: Bool) {
        do {
            // Try to get existing user
            let existingUser: User = try await firestoreService.get(collection: collection, documentId: user.id)
            return (existingUser, false)
        } catch {
            // User doesn't exist, create new one
            try await saveUser(user)
            return (user, true)
        }
    }

    func saveUser(_ user: User) async throws {
        try await firestoreService.update(collection: collection, documentId: user.id, data: user)
    }

    /// Save event ID to user's events array (Flutter pattern: FieldValue.arrayUnion)
    func saveEventId(userId: String, eventId: String) async throws {
        try await firestoreService.addToArrayField(
            collection: collection,
            documentId: userId,
            field: "events",
            value: eventId
        )
        // Also update the updateAt timestamp
        try await firestoreService.updateFields(
            collection: collection,
            documentId: userId,
            fields: ["updateAt": Date()]
        )
    }

    /// Remove event ID from user's events array (Flutter pattern: FieldValue.arrayRemove)
    func removeEventId(userId: String, eventId: String) async throws {
        try await firestoreService.removeFromArrayField(
            collection: collection,
            documentId: userId,
            field: "events",
            value: eventId
        )
        try await firestoreService.updateFields(
            collection: collection,
            documentId: userId,
            fields: ["updateAt": Date()]
        )
    }
}

// MARK: - Event Repository Implementation (gRPC + Firestore hybrid)
/// Uses gRPC for primary operations, Firestore for legacy support
class EventRepositoryImpl: EventRepositoryProtocol {
    private let firestoreService: FirestoreServiceProtocol
    private let grpcService: GRPCClientService
    private let collection = FirestoreCollections.events
    private let usersCollection = FirestoreCollections.users

    init(firestoreService: FirestoreServiceProtocol, grpcService: GRPCClientService = .shared) {
        self.firestoreService = firestoreService
        self.grpcService = grpcService
    }

    func getEvent(id: String) async throws -> Event {
        // Use gRPC to get fresh event data from the backend
        let grpcEvent = try await grpcService.getEvent(id: id)
        return Event(from: grpcEvent)
    }

    /// Get events for user by reading user's events array then fetching each event (Flutter pattern)
    func getEventsForUser(userId: String) async throws -> [Event] {
        // First get the user to read their events array
        let user: User = try await firestoreService.get(collection: usersCollection, documentId: userId)

        // Fetch all events in parallel
        guard !user.events.isEmpty else {
            return []
        }

        let events: [Event] = try await firestoreService.getByIds(
            collection: collection,
            documentIds: user.events
        )

        return events.sorted { $0.startDate < $1.startDate }
    }

    func getUpcomingEvents(userId: String) async throws -> [Event] {
        let events = try await getEventsForUser(userId: userId)
        return events.filter { $0.isUpcoming && !$0.isMovedToDraft }.sorted { $0.startDate < $1.startDate }
    }

    func getPastEvents(userId: String) async throws -> [Event] {
        let events = try await getEventsForUser(userId: userId)
        return events.filter { $0.isPast && !$0.isMovedToDraft }.sorted { $0.startDate > $1.startDate }
    }

    /// Create event with Firestore auto-generated ID (Flutter pattern)
    func createEvent(_ event: Event) async throws -> String {
        let eventId = try await firestoreService.createWithGeneratedId(collection: collection, data: event)
        return eventId
    }

    func updateEvent(_ event: Event) async throws {
        // Build gRPC update request with individual fields
        var request = Rushday_V1_UpdateEventRequest()
        request.id = event.id
        request.name = event.name
        request.date = Google_Protobuf_Timestamp(date: event.startDate)

        // Only set image if it's not nil/empty
        if let coverImage = event.coverImage, !coverImage.isEmpty {
            request.image = coverImage
        }

        request.type = event.eventTypeId

        // Set venue if available
        if let venue = event.venue, !venue.isEmpty {
            request.venue = venue
        }

        // Set custom idea if available
        if let customIdea = event.customIdea, !customIdea.isEmpty {
            request.customIdea = customIdea
        }

        // Set end date if available
        if let endDate = event.endDate {
            request.endDate = Google_Protobuf_Timestamp(date: endDate)
        }

        // Set isAllDay
        request.isAllDay = event.isAllDay

        // Set isDraft (for move to drafts functionality)
        request.isDraft = event.isMovedToDraft

        // Set invite message if available
        if let inviteMessage = event.inviteMessage, !inviteMessage.isEmpty {
            request.inviteMessage = inviteMessage
        }

        // Send gRPC update request
        _ = try await grpcService.updateEvent(request)
    }

    /// Delete event via gRPC (backend handles subcollection cleanup)
    func deleteEvent(id: String) async throws {
        _ = try await grpcService.deleteEvent(id: id)
    }

    // MARK: - JoinedUser Operations (Flutter pattern)

    /// Add owner to joinedUser subcollection when creating event
    func addJoinedUser(eventId: String, joinedUser: JoinedUser) async throws -> String {
        return try await firestoreService.createInSubcollection(
            collection: collection,
            documentId: eventId,
            subcollection: FirestoreCollections.EventSubcollections.joinedUser,
            data: joinedUser
        )
    }

    func getJoinedUsers(eventId: String) async throws -> [JoinedUser] {
        return try await firestoreService.getSubcollection(
            collection: collection,
            documentId: eventId,
            subcollection: FirestoreCollections.EventSubcollections.joinedUser
        )
    }
}

// MARK: - Guest Repository Implementation (uses gRPC)
class GuestRepositoryImpl: GuestRepositoryProtocol {
    private let grpcService: GRPCClientService

    init(grpcService: GRPCClientService = .shared) {
        self.grpcService = grpcService
    }

    func getGuest(id: String) async throws -> Guest {
        let grpcGuest = try await grpcService.getGuest(guestId: id)
        return Guest(from: grpcGuest)
    }

    func getGuestsForEvent(eventId: String) async throws -> [Guest] {
        let response = try await grpcService.listGuests(eventId: eventId)
        return response.guests.map { Guest(from: $0) }
    }

    func addGuest(_ guest: Guest) async throws -> String {
        let request = guest.toCreateRequest()
        let grpcGuest = try await grpcService.createGuest(request)
        return grpcGuest.id
    }

    func updateGuest(_ guest: Guest) async throws {
        let request = guest.toUpdateRequest()
        _ = try await grpcService.updateGuest(request)
    }

    func removeGuest(id: String, eventId: String) async throws {
        _ = try await grpcService.deleteGuest(guestId: id)
    }

    func updateRSVP(guestId: String, status: RSVPStatus) async throws {
        // Get current guest, update status, and save
        let grpcGuest = try await grpcService.getGuest(guestId: guestId)
        var guest = Guest(from: grpcGuest)
        guest.rsvpStatus = status
        try await updateGuest(guest)
    }
}

// MARK: - Task Repository Implementation (uses gRPC)
class TaskRepositoryImpl: TaskRepositoryProtocol {
    private let grpcService: GRPCClientService

    init(grpcService: GRPCClientService = .shared) {
        self.grpcService = grpcService
    }

    func getTask(id: String) async throws -> EventTask {
        fatalError("Use getTasksForEvent instead - tasks are fetched by event")
    }

    func getTasksForEvent(eventId: String) async throws -> [EventTask] {
        let response = try await grpcService.listTasks(eventId: eventId)
        return response.tasks.map { $0.toEventTask() }
    }

    func createTask(_ task: EventTask, eventId: String) async throws -> EventTask {
        var request = Rushday_V1_CreateTaskRequest()
        request.eventID = eventId
        request.name = task.title
        if let notes = task.description {
            request.notes = notes
        }
        if let dueDate = task.dueDate {
            request.notification = Google_Protobuf_Timestamp(date: dueDate)
        }
        // Note: gRPC Task doesn't support isDone, vendorId on creation

        let createdTask = try await grpcService.createTask(request)
        return createdTask.toEventTask()
    }

    func createTask(_ task: EventTask) async throws -> EventTask {
        guard let eventId = task.eventId else {
            throw FirestoreError.invalidData
        }
        return try await createTask(task, eventId: eventId)
    }

    func updateTask(_ task: EventTask, eventId: String) async throws {
        var request = Rushday_V1_UpdateTaskRequest()
        request.id = task.id
        request.name = task.title
        if let notes = task.description {
            request.notes = notes
        }
        if let dueDate = task.dueDate {
            request.notification = Google_Protobuf_Timestamp(date: dueDate)
        }
        // Note: gRPC Task doesn't support isDone, vendorId on update

        _ = try await grpcService.updateTask(request)
    }

    func updateTask(_ task: EventTask) async throws {
        guard let eventId = task.eventId else {
            throw FirestoreError.invalidData
        }
        try await updateTask(task, eventId: eventId)
    }

    func deleteTask(id: String, eventId: String) async throws {
        _ = try await grpcService.deleteTask(id: id)
    }

    func deleteTask(id: String) async throws {
        _ = try await grpcService.deleteTask(id: id)
    }

    func updateTaskStatus(taskId: String, status: TaskStatus) async throws {
        _ = try await grpcService.toggleTaskDone(id: taskId)
    }

    func reorderTasks(eventId: String, taskIds: [String]) async throws -> [EventTask] {
        let response = try await grpcService.reorderTasks(eventId: eventId, taskIds: taskIds)
        return response.tasks.map { $0.toEventTask() }
    }
}

// MARK: - Task gRPC Mapping Extension
extension Rushday_V1_Task {
    func toEventTask() -> EventTask {
        return EventTask(
            id: self.id,
            eventId: self.eventID,
            title: self.name,
            description: self.notes.isEmpty ? nil : self.notes,
            status: self.isDone ? .completed : .pending,
            priority: .medium, // gRPC doesn't have priority yet
            dueDate: self.hasNotification ? self.notification.date : nil,
            assignedTo: [], // gRPC doesn't have assignedTo yet
            category: nil, // gRPC vendorID maps to category conceptually, but keeping nil for now
            estimatedCost: nil,
            actualCost: nil,
            attachments: [],
            createdBy: "", // gRPC doesn't have createdBy
            createdAt: self.hasCreatedAt ? self.createdAt.date : Date(),
            updatedAt: self.hasUpdatedAt ? self.updatedAt.date : Date(),
            order: Int(self.orderNumber)
        )
    }
}

// MARK: - Expense Repository Implementation (uses gRPC Budget API)
class ExpenseRepositoryImpl: ExpenseRepositoryProtocol {
    private let grpcService: GRPCClientService

    init(grpcService: GRPCClientService = .shared) {
        self.grpcService = grpcService
    }

    func getExpense(id: String) async throws -> Expense {
        fatalError("Use getExpensesForEvent instead - expenses are fetched by event")
    }

    func getExpensesForEvent(eventId: String) async throws -> [Expense] {
        let response = try await grpcService.listBudgets(eventId: eventId)
        return response.budgets.map { $0.toExpense() }
    }

    func createExpense(_ expense: Expense, eventId: String) async throws -> String {
        var request = Rushday_V1_CreateBudgetRequest()
        request.eventID = eventId
        request.title = expense.title
        request.totalAmount = Int64(expense.amount.rounded())
        if let notes = expense.notes {
            request.notes = notes
        }
        request.date = Google_Protobuf_Timestamp(date: expense.createdAt)

        let createdBudget = try await grpcService.createBudget(request)
        return createdBudget.id
    }

    func createExpense(_ expense: Expense) async throws -> String {
        guard let eventId = expense.eventId else {
            throw FirestoreError.invalidData
        }
        return try await createExpense(expense, eventId: eventId)
    }

    func updateExpense(_ expense: Expense, eventId: String) async throws {
        var request = Rushday_V1_UpdateBudgetRequest()
        request.id = expense.id
        request.title = expense.title
        request.totalAmount = Int64(expense.amount.rounded())
        if let notes = expense.notes {
            request.notes = notes
        }
        request.date = Google_Protobuf_Timestamp(date: expense.updatedAt)

        _ = try await grpcService.updateBudget(request)
    }

    func updateExpense(_ expense: Expense) async throws {
        guard let eventId = expense.eventId else {
            throw FirestoreError.invalidData
        }
        try await updateExpense(expense, eventId: eventId)
    }

    func deleteExpense(id: String, eventId: String) async throws {
        _ = try await grpcService.deleteBudget(id: id)
    }

    func deleteExpense(id: String) async throws {
        _ = try await grpcService.deleteBudget(id: id)
    }

    func getTotalExpenses(eventId: String) async throws -> Double {
        let expenses = try await getExpensesForEvent(eventId: eventId)
        return expenses.reduce(0) { $0 + $1.amount }
    }

    func addPayment(expenseId: String, amount: Double) async throws -> Expense {
        var request = Rushday_V1_AddPaymentRequest()
        request.budgetID = expenseId
        request.amount = Int64(amount.rounded())
        request.date = Google_Protobuf_Timestamp(date: Date())

        let updatedBudget = try await grpcService.addPayment(request)
        return updatedBudget.toExpense()
    }

    func removePayment(expenseId: String) async throws -> Expense {
        var request = Rushday_V1_RemovePaymentRequest()
        request.budgetID = expenseId

        let updatedBudget = try await grpcService.removePayment(request)
        return updatedBudget.toExpense()
    }
}

// MARK: - Budget gRPC Mapping Extension
extension Rushday_V1_Budget {
    func toExpense() -> Expense {
        // Map gRPC Budget to Expense entity
        // Note: Backend Budget is simpler than frontend Expense model
        let totalAmount = Double(self.totalAmount)
        let paidAmount = self.payments.reduce(0.0) { $0 + Double($1.amount) }

        // Determine payment status based on paid amount vs total amount
        let status: PaymentStatus
        if self.payments.isEmpty {
            status = .pending
        } else if paidAmount >= totalAmount {
            status = .paid
        } else {
            status = .partial
        }

        return Expense(
            id: self.id,
            eventId: self.eventID,
            title: self.title,
            description: self.notes.isEmpty ? nil : self.notes,
            category: .other, // gRPC doesn't have category - default to "other"
            amount: totalAmount,
            paidAmount: paidAmount,
            currency: "USD", // gRPC doesn't specify currency
            paymentStatus: status,
            vendorId: nil, // gRPC Budget doesn't have vendor
            vendorName: nil,
            dueDate: self.hasDate ? self.date.date : nil,
            paidDate: nil, // gRPC doesn't track paid date
            receiptURL: nil, // gRPC doesn't have receipt
            notes: self.notes.isEmpty ? nil : self.notes,
            createdBy: "", // gRPC doesn't have createdBy
            createdAt: self.hasCreatedAt ? self.createdAt.date : Date(),
            updatedAt: self.hasUpdatedAt ? self.updatedAt.date : Date()
        )
    }
}

// MARK: - Agenda Repository Implementation (uses gRPC)
class AgendaRepositoryImpl: AgendaRepositoryProtocol {
    private let grpcService: GRPCClientService

    init(grpcService: GRPCClientService = .shared) {
        self.grpcService = grpcService
    }

    func getAgendaItem(id: String) async throws -> AgendaItem {
        fatalError("Use getAgendaForEvent instead - agendas are fetched by event")
    }

    func getAgendaForEvent(eventId: String) async throws -> [AgendaItem] {
        let response = try await grpcService.listAgendas(eventId: eventId)
        // Sort by startTime since gRPC doesn't have order field
        return response.agendas.map { $0.toAgendaItem() }.sorted { $0.startTime < $1.startTime }
    }

    func createAgendaItem(_ item: AgendaItem, eventId: String) async throws -> String {
        var request = Rushday_V1_CreateAgendaRequest()
        request.eventID = eventId
        request.title = item.title
        if let notes = item.description {
            request.notes = notes
        }
        // Set the date field (required by backend) - use start of day from startTime
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: item.startTime)
        request.date = Google_Protobuf_Timestamp(date: dateOnly)
        request.startTime = Google_Protobuf_Timestamp(date: item.startTime)
        if let endTime = item.endTime {
            request.endTime = Google_Protobuf_Timestamp(date: endTime)
        }
        // Note: gRPC doesn't support location or orderNum fields yet

        let createdAgenda = try await grpcService.createAgenda(request)
        return createdAgenda.id
    }

    func createAgendaItem(_ item: AgendaItem) async throws -> String {
        guard let eventId = item.eventId else {
            throw FirestoreError.invalidData
        }
        return try await createAgendaItem(item, eventId: eventId)
    }

    func updateAgendaItem(_ item: AgendaItem, eventId: String) async throws {
        var request = Rushday_V1_UpdateAgendaRequest()
        request.id = item.id
        request.title = item.title
        if let notes = item.description {
            request.notes = notes
        }
        // Set the date field - use start of day from startTime
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: item.startTime)
        request.date = Google_Protobuf_Timestamp(date: dateOnly)
        request.startTime = Google_Protobuf_Timestamp(date: item.startTime)
        if let endTime = item.endTime {
            request.endTime = Google_Protobuf_Timestamp(date: endTime)
        }
        // Note: gRPC doesn't support location or orderNum fields yet

        _ = try await grpcService.updateAgenda(request)
    }

    func updateAgendaItem(_ item: AgendaItem) async throws {
        guard let eventId = item.eventId else {
            throw FirestoreError.invalidData
        }
        try await updateAgendaItem(item, eventId: eventId)
    }

    func deleteAgendaItem(id: String, eventId: String) async throws {
        _ = try await grpcService.deleteAgenda(id: id)
    }

    func deleteAgendaItem(id: String) async throws {
        _ = try await grpcService.deleteAgenda(id: id)
    }

    func reorderAgenda(eventId: String, itemIds: [String]) async throws {
        var items = try await getAgendaForEvent(eventId: eventId)
        for (index, itemId) in itemIds.enumerated() {
            if let itemIndex = items.firstIndex(where: { $0.id == itemId }) {
                items[itemIndex].order = index
                try await updateAgendaItem(items[itemIndex], eventId: eventId)
            }
        }
    }
}

// MARK: - Agenda gRPC Mapping Extension
extension Rushday_V1_Agenda {
    func toAgendaItem() -> AgendaItem {
        return AgendaItem(
            id: self.id,
            eventId: self.eventID,
            title: self.title,
            description: self.notes.isEmpty ? nil : self.notes,
            startTime: self.hasStartTime ? self.startTime.date : Date(),
            endTime: self.hasEndTime ? self.endTime.date : nil,
            location: nil, // gRPC doesn't have location field
            speakerId: nil, // gRPC doesn't have speaker fields
            speakerName: nil,
            isBreak: false, // gRPC doesn't have isBreak field
            order: 0, // gRPC doesn't have order field - will need client-side sorting
            createdAt: self.hasCreatedAt ? self.createdAt.date : Date(),
            updatedAt: self.hasUpdatedAt ? self.updatedAt.date : Date()
        )
    }
}

// MARK: - Notification Repository Implementation
/// Manages scheduled push notifications via the notification service API.
class NotificationRepositoryImpl: NotificationRepositoryProtocol {
    private let networkService: NotificationNetworkServiceProtocol
    private let fcmService: FCMNotificationServiceImpl

    init(
        networkService: NotificationNetworkServiceProtocol = NotificationNetworkService(),
        fcmService: FCMNotificationServiceImpl = FCMNotificationServiceImpl()
    ) {
        self.networkService = networkService
        self.fcmService = fcmService
    }

    func getFcmToken() async throws -> String? {
        do {
            return try await fcmService.getFCMToken()
        } catch {
            // Error handled silently
            return nil
        }
    }

    func createNotification(_ request: CreateNotificationRequest) async throws -> Bool {
        return try await networkService.createNotification(request)
    }

    func createNotificationsBatch(_ requests: [CreateNotificationRequest]) async throws -> Bool {
        guard !requests.isEmpty else { return true }
        return try await networkService.createNotificationsBatch(requests)
    }

    func updateNotificationsByGroup(
        groupField: GroupField,
        groupValue: String,
        title: String?,
        body: String?,
        sendAt: Date?,
        data: [String: AnyCodable]?
    ) async throws -> Bool {
        return try await networkService.updateNotificationsByGroup(
            groupField: groupField,
            groupValue: groupValue,
            title: title,
            body: body,
            sendAt: sendAt,
            data: data
        )
    }

    func deleteNotificationsByGroup(
        groupField: GroupField,
        groupValue: String
    ) async throws -> Bool {
        return try await networkService.deleteNotificationsByGroup(
            groupField: groupField,
            groupValue: groupValue
        )
    }

    func deleteUserNotificationFromGroup(
        groupField: GroupField,
        groupValue: String,
        userId: String
    ) async throws -> Bool {
        return try await networkService.deleteUserNotificationFromGroup(
            groupField: groupField,
            groupValue: groupValue,
            userId: userId
        )
    }

    func deleteNotificationsBatch(_ filters: [[String: String]]) async throws -> Bool {
        guard !filters.isEmpty else { return true }
        return try await networkService.deleteNotificationsBatch(filters)
    }

    func editNotificationPeriodByType(
        userId: String,
        type: NotificationType,
        deltaMs: Int
    ) async throws -> Bool {
        return try await networkService.editNotificationPeriodByType(
            userId: userId,
            type: type,
            deltaMs: deltaMs
        )
    }

    func toggleNotificationType(
        userId: String,
        type: NotificationType,
        enabled: Bool
    ) async throws -> Bool {
        return try await networkService.toggleNotificationType(
            userId: userId,
            type: type,
            enabled: enabled
        )
    }
}
