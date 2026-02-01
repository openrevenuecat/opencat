import Foundation
import SwiftUI

// MARK: - AI Event Chat ViewModel
@MainActor
class AIEventChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var isStreamingComplete: Bool = true  // True when no active streaming
    @Published var savedConversations: [SavedConversation] = []
    @Published var isLoadingSaved: Bool = false
    @Published var error: String?
    @Published var hintText: String = ""
    @Published var scrollToMessageId: String?
    @Published var pendingChecklistId: String?  // Set when returning from saved page
    @Published var pendingConversationId: String?  // Conversation to load when returning from saved page

    let event: Event
    private let grpcClient = GRPCClientService.shared
    private var conversationId: String?
    private var suggestedHints: [String] = []
    private var currentHintIndex = 0
    private var hintRotationTimer: Timer?
    private var lastTopic: Rushday_V1_ChatTopic?
    private var sendTask: Task<Void, Never>?

    init(event: Event) {
        self.event = event
        // Start with fallback hint, then fetch AI-generated hints
        self.hintText = generateFallbackHint(for: event)
    }

    deinit {
        hintRotationTimer?.invalidate()
        sendTask?.cancel()
    }

    /// Stop hint rotation when view disappears
    func stopHintRotation() {
        hintRotationTimer?.invalidate()
        hintRotationTimer = nil
    }

    /// Cancel any ongoing streaming task (call when view disappears)
    func cancelSendTask() {
        sendTask?.cancel()
        sendTask = nil
        isTyping = false
    }

    /// Fallback hint generated client-side (used when backend unavailable)
    private func generateFallbackHint(for event: Event) -> String {
        switch event.eventType {
        case .wedding:
            return "Ask about venues, catering, or wedding day timeline..."
        case .birthday:
            return "Ask about themes, decorations, or birthday activities..."
        case .babyShower:
            return "Ask about themes, games, or gift registry ideas..."
        case .graduation:
            return "Ask about venues, photo ideas, or celebration themes..."
        case .anniversary:
            return "Ask about romantic venues, gift ideas, or surprises..."
        case .corporate, .conference:
            return "Ask about venues, catering, or presentation setup..."
        case .holiday:
            return "Ask about themes, decorations, or celebration ideas..."
        case .vacation:
            return "Ask about destinations, activities, or packing tips..."
        case .custom:
            let shortName = String(event.name.prefix(20))
            return "Ask about planning \(shortName)..."
        }
    }

    /// Load AI-generated hints from backend and start rotation
    func loadChatHints() async {
        do {
            let result = try await grpcClient.getChatHints(
                eventId: event.id,
                conversationId: conversationId,
                lastTopic: lastTopic
            )

            // Update primary hint
            if !result.primaryHint.isEmpty {
                hintText = result.primaryHint
            }

            // Store suggested hints for rotation
            if !result.suggestedHints.isEmpty {
                suggestedHints = result.suggestedHints
                startHintRotation()
            }
        } catch {
            // Keep fallback hint on error
        }
    }

    /// Start rotating through suggested hints
    private func startHintRotation() {
        hintRotationTimer?.invalidate()
        currentHintIndex = 0

        // Rotate every 8 seconds
        hintRotationTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rotateHint()
            }
        }
    }

    /// Rotate to the next suggested hint
    private func rotateHint() {
        guard !suggestedHints.isEmpty else { return }

        currentHintIndex = (currentHintIndex + 1) % suggestedHints.count
        withAnimation(.easeInOut(duration: 0.3)) {
            hintText = suggestedHints[currentHintIndex]
        }
    }

    /// Update hints based on new context (called after interactions)
    private func updateHint(_ newHint: String) {
        guard !newHint.isEmpty else { return }

        // Stop rotation when we get context-specific hints
        hintRotationTimer?.invalidate()
        suggestedHints = []

        withAnimation(.easeInOut(duration: 0.3)) {
            hintText = newHint
        }
    }

    /// Load chat on view appear - fetches messages from backend and AI-generated hints
    func loadChatHistory() async {
        // Load chat messages from backend
        do {
            let (protoMessages, _) = try await grpcClient.getChatHistory(eventId: event.id)

            // Convert proto messages to local models
            let loadedMessages = protoMessages.map { AIChatMessage(from: $0) }

            // Only update if we got messages and don't already have local messages
            if !loadedMessages.isEmpty && messages.isEmpty {
                messages = loadedMessages

                // Set conversationId from first message if available
                if let firstMessage = protoMessages.first, !firstMessage.conversationID.isEmpty {
                    conversationId = firstMessage.conversationID
                }
            }
        } catch {
            // Error handled silently
        }

        // Fetch AI-generated contextual hints
        await loadChatHints()
    }

    /// Load saved conversations from backend
    func loadSavedConversations() async {
        isLoadingSaved = true
        defer { isLoadingSaved = false }

        do {
            let conversations = try await grpcClient.getSavedConversations(eventId: event.id)
            savedConversations = conversations.map { SavedConversation(from: $0) }
        } catch {
            // Error handled silently
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = AIChatMessage(
            content: inputText,
            isUser: true
        )
        messages.append(userMessage)
        let messageText = inputText
        inputText = ""

        // Cancel any previous send task
        sendTask?.cancel()

        // Send to backend with context (lastTopic for continuity)
        isTyping = true
        isStreamingComplete = false
        sendTask = Task {
            await sendToBackend(message: messageText, topic: lastTopic ?? .general)
        }
    }

    func selectTopic(_ topic: AITopicType) {
        let userMessage = AIChatMessage(
            content: topic.prompt,
            isUser: true
        )
        messages.append(userMessage)

        // Cancel any previous send task
        sendTask?.cancel()

        // Send as regular chat message with topic context
        isTyping = true
        isStreamingComplete = false
        lastTopic = topic.protoTopic
        sendTask = Task {
            await sendToBackend(message: topic.prompt, topic: topic.protoTopic)
        }
    }

    private func sendToBackend(message: String, topic: Rushday_V1_ChatTopic = .general) async {
        // Use streaming for real-time response
        await sendToBackendStreaming(message: message, topic: topic)
    }

    /// Send message with streaming response for real-time text appearance
    private func sendToBackendStreaming(message: String, topic: Rushday_V1_ChatTopic = .general) async {
        // Create placeholder AI message that will be updated as stream comes in
        let placeholderMessage = AIChatMessage(
            content: "",
            isUser: false
        )
        messages.append(placeholderMessage)
        let aiMessageIndex = messages.count - 1

        // Track streaming state
        var streamedContent = ""
        var toolExecutions: [ToolExecution] = []
        var suggestedAction: SuggestedAction?
        var checklist: AIChatChecklist?
        var receivedConversationId: String?
        var hintText: String = ""

        do {
            let stream = grpcClient.sendChatMessageStream(
                eventId: event.id,
                message: message,
                topic: topic
            )

            for try await response in stream {
                switch response.payload {
                case .toolExecution(let toolExec):
                    // Keep typing indicator active - will stop when text starts flowing
                    // This shows the user that AI is still working after tool executions

                    let execution = ToolExecution(
                        toolName: toolExec.toolName,
                        status: toolExec.status,
                        summary: toolExec.summary
                    )

                    // If this is a final status (success/error), replace any in_progress execution for the same tool
                    if toolExec.status != "in_progress" {
                        toolExecutions.removeAll { $0.toolName == toolExec.toolName && $0.isInProgress }
                    }

                    // Add/update tool execution
                    toolExecutions.append(execution)

                    // Update message with tool executions - create new message to trigger view update
                    messages[aiMessageIndex] = AIChatMessage(
                        id: messages[aiMessageIndex].id,
                        content: streamedContent,
                        isUser: false,
                        timestamp: messages[aiMessageIndex].timestamp,
                        isSaved: false,
                        checklist: nil,
                        suggestedAction: nil,
                        actionApplied: false,
                        checklistTasksAdded: false,
                        toolExecutions: toolExecutions
                    )

                case .delta(let delta):
                    // Stop typing indicator once text starts flowing
                    isTyping = false

                    // Append text chunk to content
                    streamedContent += delta.text

                    // Update message content progressively with smooth animation
                    withAnimation(.easeOut(duration: 0.15)) {
                        messages[aiMessageIndex] = AIChatMessage(
                            id: messages[aiMessageIndex].id,
                            content: streamedContent,
                            isUser: false,
                            timestamp: messages[aiMessageIndex].timestamp,
                            isSaved: false,
                            checklist: nil,
                            suggestedAction: nil,
                            actionApplied: false,
                            checklistTasksAdded: false,
                            toolExecutions: toolExecutions.isEmpty ? nil : toolExecutions
                        )
                    }

                    if !delta.conversationID.isEmpty {
                        receivedConversationId = delta.conversationID
                    }

                case .complete(let complete):
                    // Store conversation ID
                    if !complete.conversationID.isEmpty {
                        receivedConversationId = complete.conversationID
                    }

                    // Get final content from full message
                    if complete.hasFullMessage {
                        streamedContent = complete.fullMessage.content

                        // Parse checklist if present
                        if complete.fullMessage.hasChecklist {
                            checklist = AIChatChecklist(from: complete.fullMessage.checklist)
                        }
                    }

                    // Get hint text
                    hintText = complete.hintText

                    // Parse suggested action if present
                    if complete.hasSuggestedAction {
                        suggestedAction = SuggestedAction(from: complete.suggestedAction)
                    }

                    // Get tool executions from complete event
                    if !complete.toolExecutions.isEmpty {
                        toolExecutions = complete.toolExecutions.map { ToolExecution(from: $0) }
                    }

                case .error(let error):
                    throw GRPCError.serverError(error.message)

                case .none:
                    break
                }
            }

            // Update conversation ID for continuity
            if let convId = receivedConversationId {
                conversationId = convId
            }

            // Update hint with context-aware hint from response
            if !hintText.isEmpty {
                updateHint(hintText)
            }

            // Update final message with all data
            messages[aiMessageIndex] = AIChatMessage(
                id: messages[aiMessageIndex].id,
                content: streamedContent,
                isUser: false,
                timestamp: messages[aiMessageIndex].timestamp,
                isSaved: checklist?.isSaved ?? false,
                checklist: checklist,
                suggestedAction: suggestedAction,
                actionApplied: false,
                checklistTasksAdded: false,
                toolExecutions: toolExecutions.isEmpty ? nil : toolExecutions
            )

            isTyping = false
            isStreamingComplete = true

        } catch {
            isTyping = false
            isStreamingComplete = true
            self.error = error.localizedDescription

            // Update placeholder with error message
            messages[aiMessageIndex] = AIChatMessage(
                id: messages[aiMessageIndex].id,
                content: "Sorry, I couldn't process your message. Please try again.",
                isUser: false,
                timestamp: messages[aiMessageIndex].timestamp
            )
        }
    }

    /// Non-streaming fallback (kept for reference)
    private func sendToBackendNonStreaming(message: String, topic: Rushday_V1_ChatTopic = .general) async {
        defer { isTyping = false }

        do {
            let result = try await grpcClient.sendChatMessage(
                eventId: event.id,
                message: message,
                topic: topic,
                conversationId: conversationId
            )

            // Store conversation ID for continuity
            if !result.conversationId.isEmpty {
                conversationId = result.conversationId
            }

            // Update hint with AI-generated context-aware hint
            updateHint(result.hintText)

            // Create AI message from response
            var aiMessage = AIChatMessage(from: result.message)

            // Parse suggested action if present
            if let protoAction = result.suggestedAction {
                aiMessage.suggestedAction = SuggestedAction(from: protoAction)
            }

            // Parse tool executions if present
            if !result.toolExecutions.isEmpty {
                aiMessage.toolExecutions = result.toolExecutions.map { ToolExecution(from: $0) }
            }

            messages.append(aiMessage)
        } catch {
            self.error = error.localizedDescription
            // Add error message to chat
            let errorMessage = AIChatMessage(
                content: "Sorry, I couldn't process your message. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
        }
    }

    // MARK: - Apply Suggested Actions

    /// Apply suggested action for a message
    func applySuggestedAction(messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              let action = messages[index].suggestedAction,
              !messages[index].actionApplied else {
            return
        }

        // Mark as applied immediately for optimistic UI
        messages[index].actionApplied = true

        Task {
            do {
                switch action.actionType {
                case .addTasks:
                    try await addTasksFromAction(action.items)
                case .removeTasks:
                    try await removeTasksFromAction(action.items)
                case .updateTasks:
                    try await updateTasksFromAction(action.items)
                case .addAgenda:
                    try await addAgendaFromAction(action.items)
                case .removeAgenda:
                    try await removeAgendaFromAction(action.items)
                case .updateAgenda:
                    try await updateAgendaFromAction(action.items)
                case .addExpenses:
                    try await addExpensesFromAction(action.items)
                case .removeExpenses:
                    try await removeExpensesFromAction(action.items)
                case .updateExpenses:
                    try await updateExpensesFromAction(action.items)
                case .updateBudget:
                    try await updateBudgetFromAction(action.items)
                case .none:
                    break
                }

                // Add confirmation message after successful action
                await MainActor.run {
                    let confirmationMessage = AIChatMessage(
                        content: buildConfirmationMessage(for: action),
                        isUser: false
                    )
                    messages.append(confirmationMessage)
                }
            } catch {
                // Rollback on failure
                if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[idx].actionApplied = false
                }
                self.error = "Failed to apply action: \(error.localizedDescription)"
            }
        }
    }

    /// Build a friendly confirmation message for a completed action
    private func buildConfirmationMessage(for action: SuggestedAction) -> String {
        let count = action.items.count
        let plural = count == 1 ? "" : "s"

        switch action.actionType {
        case .addTasks:
            return "Done! I've added \(count) task\(plural) to your list. What else would you like help with?"
        case .removeTasks:
            return "Done! I've removed \(count) task\(plural) from your list. Anything else?"
        case .updateTasks:
            return "Done! I've updated \(count) task\(plural). Let me know if you need anything else!"
        case .addAgenda:
            return "Done! I've added \(count) item\(plural) to your agenda. Would you like to make any changes?"
        case .removeAgenda:
            return "Done! I've removed \(count) item\(plural) from your agenda. What's next?"
        case .updateAgenda:
            return "Done! I've updated \(count) agenda item\(plural). Anything else to adjust?"
        case .addExpenses:
            return "Done! I've added \(count) expense\(plural) to track. Need help with anything else?"
        case .removeExpenses:
            return "Done! I've removed \(count) expense\(plural). What else can I help with?"
        case .updateExpenses:
            return "Done! I've updated \(count) expense\(plural). Let me know if you need more changes!"
        case .updateBudget:
            if let item = action.items.first {
                return "Done! I've updated your budget to $\(item.amount). What else can I help with?"
            }
            return "Done! I've updated your budget. What else can I help with?"
        case .none:
            return "Done! What else can I help you with?"
        }
    }

    /// Decline suggested action for a message
    func declineSuggestedAction(messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        // Clear the suggested action so buttons disappear
        messages[index].suggestedAction = nil
    }

    // MARK: - Add Checklist Items to Event

    /// Add unchecked checklist items based on topic (tasks, agenda, or expenses)
    func addChecklistItems(messageId: String) {
        print("🔵 [AIChat] addChecklistItems called for messageId: \(messageId)")

        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              let checklist = messages[index].checklist,
              !messages[index].checklistTasksAdded else {
            print("⚠️ [AIChat] Guard failed - message not found, no checklist, or already added")
            return
        }

        // Get unchecked items
        let uncheckedItems = checklist.items.filter { !$0.isChecked }
        print("🔵 [AIChat] Found \(uncheckedItems.count) unchecked items, topic: \(String(describing: checklist.topic))")

        guard !uncheckedItems.isEmpty else {
            print("⚠️ [AIChat] No unchecked items to add")
            return
        }

        // Mark as added immediately for optimistic UI
        messages[index].checklistTasksAdded = true

        // Determine action type based on checklist topic
        let actionType = ChecklistActionType.from(topic: checklist.topic)
        print("🔵 [AIChat] Action type: \(actionType)")

        Task {
            do {
                switch actionType {
                case .tasks:
                    try await addChecklistItemsAsTasks(uncheckedItems)
                case .agenda:
                    try await addChecklistItemsAsAgenda(uncheckedItems)
                case .expenses:
                    try await addChecklistItemsAsExpenses(uncheckedItems)
                }
                print("✅ [AIChat] Items added successfully")
            } catch {
                print("❌ [AIChat] Error adding items: \(error)")
                // Rollback on failure
                if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[idx].checklistTasksAdded = false
                }
                self.error = "Failed to add items: \(error.localizedDescription)"
            }
        }
    }

    private func addChecklistItemsAsTasks(_ items: [AIChatChecklistItem]) async throws {
        let taskRepository = DIContainer.shared.taskRepository
        print("🔵 [AIChat] Adding \(items.count) checklist items as tasks for event: \(event.id)")

        for (index, item) in items.enumerated() {
            print("🔵 [AIChat] Creating task \(index + 1)/\(items.count): \(item.text)")

            let task = EventTask(
                eventId: event.id,
                title: item.text,
                description: nil,
                status: .pending,
                priority: .medium,
                dueDate: nil,
                assignedTo: [],
                category: nil,
                attachments: [],
                createdBy: "",
                createdAt: Date(),
                updatedAt: Date(),
                order: 0
            )

            do {
                let createdTask = try await taskRepository.createTask(task)
                print("✅ [AIChat] Task created with ID: \(createdTask.id)")
            } catch {
                print("❌ [AIChat] Failed to create task: \(error)")
                throw error
            }
        }

        print("✅ [AIChat] All \(items.count) tasks created successfully")
    }

    private func addChecklistItemsAsAgenda(_ items: [AIChatChecklistItem]) async throws {
        let agendaRepository = DIContainer.shared.agendaRepository
        var startTime = event.startDate

        for item in items {
            // Each agenda item is 30 minutes by default, starting from event start time
            let endTime = startTime.addingTimeInterval(30 * 60)

            let agendaItem = AgendaItem(
                eventId: event.id,
                title: item.text,
                description: nil,
                startTime: startTime,
                endTime: endTime,
                isBreak: false,
                order: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await agendaRepository.createAgendaItem(agendaItem)

            // Move start time forward for next item
            startTime = endTime
        }
    }

    private func addChecklistItemsAsExpenses(_ items: [AIChatChecklistItem]) async throws {
        let expenseRepository = DIContainer.shared.expenseRepository
        for item in items {
            let expense = Expense(
                eventId: event.id,
                title: item.text,
                description: nil,
                category: .other,
                amount: 0,  // User will fill in the amount
                paidAmount: 0,
                currency: "USD",
                paymentStatus: .pending,
                createdBy: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await expenseRepository.createExpense(expense)
        }
    }

    private func addTasksFromAction(_ items: [SuggestedActionItem]) async throws {
        let taskRepository = DIContainer.shared.taskRepository
        for item in items {
            let task = EventTask(
                eventId: event.id,
                title: item.title,
                description: item.description.isEmpty ? nil : item.description,
                status: .pending,
                priority: .medium,
                assignedTo: [],
                category: item.category.isEmpty ? nil : item.category,
                attachments: [],
                createdBy: "",
                createdAt: Date(),
                updatedAt: Date(),
                order: 0
            )
            _ = try await taskRepository.createTask(task)
        }
    }

    private func addAgendaFromAction(_ items: [SuggestedActionItem]) async throws {
        let agendaRepository = DIContainer.shared.agendaRepository
        for item in items {
            // Parse start time from HH:MM format
            var startTime: Date = event.startDate
            if !item.startTime.isEmpty {
                let components = item.startTime.split(separator: ":")
                if components.count == 2,
                   let hour = Int(components[0]),
                   let minute = Int(components[1]) {
                    var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: event.startDate)
                    dateComponents.hour = hour
                    dateComponents.minute = minute
                    if let parsed = Calendar.current.date(from: dateComponents) {
                        startTime = parsed
                    }
                }
            }

            // Calculate end time
            var endTime: Date? = nil
            if item.durationMinutes > 0 {
                endTime = startTime.addingTimeInterval(TimeInterval(item.durationMinutes * 60))
            }

            let agendaItem = AgendaItem(
                eventId: event.id,
                title: item.title,
                description: item.description.isEmpty ? nil : item.description,
                startTime: startTime,
                endTime: endTime,
                isBreak: false,
                order: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await agendaRepository.createAgendaItem(agendaItem)
        }
    }

    private func addExpensesFromAction(_ items: [SuggestedActionItem]) async throws {
        let expenseRepository = DIContainer.shared.expenseRepository
        for item in items {
            let expense = Expense(
                eventId: event.id,
                title: item.title,
                description: item.description.isEmpty ? nil : item.description,
                category: .other,
                amount: Double(item.amount) / 100.0,  // Convert cents to dollars
                paidAmount: 0,
                currency: "USD",
                paymentStatus: .pending,
                createdBy: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await expenseRepository.createExpense(expense)
        }
    }

    // MARK: - Remove Action Handlers

    private func removeTasksFromAction(_ items: [SuggestedActionItem]) async throws {
        let taskRepository = DIContainer.shared.taskRepository
        let existingTasks = try await taskRepository.getTasksForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            if !item.existingItemId.isEmpty,
               existingTasks.contains(where: { $0.id == item.existingItemId }) {
                print("🗑️ [AIChat] Removing task by ID: \(item.existingItemId)")
                try await taskRepository.deleteTask(id: item.existingItemId)
            } else if let taskToRemove = existingTasks.first(where: {
                $0.title.lowercased().contains(item.title.lowercased()) ||
                item.title.lowercased().contains($0.title.lowercased())
            }) {
                print("🗑️ [AIChat] Removing task by title match: \(taskToRemove.title)")
                try await taskRepository.deleteTask(id: taskToRemove.id)
            } else {
                print("⚠️ [AIChat] Could not find task to remove: \(item.title)")
            }
        }
    }

    private func removeAgendaFromAction(_ items: [SuggestedActionItem]) async throws {
        let agendaRepository = DIContainer.shared.agendaRepository
        let existingAgenda = try await agendaRepository.getAgendaForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            if !item.existingItemId.isEmpty,
               existingAgenda.contains(where: { $0.id == item.existingItemId }) {
                print("🗑️ [AIChat] Removing agenda by ID: \(item.existingItemId)")
                try await agendaRepository.deleteAgendaItem(id: item.existingItemId)
            } else if let itemToRemove = existingAgenda.first(where: {
                $0.title.lowercased().contains(item.title.lowercased()) ||
                item.title.lowercased().contains($0.title.lowercased())
            }) {
                print("🗑️ [AIChat] Removing agenda by title match: \(itemToRemove.title)")
                try await agendaRepository.deleteAgendaItem(id: itemToRemove.id)
            } else {
                print("⚠️ [AIChat] Could not find agenda item to remove: \(item.title)")
            }
        }
    }

    private func removeExpensesFromAction(_ items: [SuggestedActionItem]) async throws {
        let expenseRepository = DIContainer.shared.expenseRepository
        let existingExpenses = try await expenseRepository.getExpensesForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            if !item.existingItemId.isEmpty,
               existingExpenses.contains(where: { $0.id == item.existingItemId }) {
                print("🗑️ [AIChat] Removing expense by ID: \(item.existingItemId)")
                try await expenseRepository.deleteExpense(id: item.existingItemId)
            } else if let expenseToRemove = existingExpenses.first(where: {
                $0.title.lowercased().contains(item.title.lowercased()) ||
                item.title.lowercased().contains($0.title.lowercased())
            }) {
                print("🗑️ [AIChat] Removing expense by title match: \(expenseToRemove.title)")
                try await expenseRepository.deleteExpense(id: expenseToRemove.id)
            } else {
                print("⚠️ [AIChat] Could not find expense to remove: \(item.title)")
            }
        }
    }

    // MARK: - Update Action Handlers

    private func updateTasksFromAction(_ items: [SuggestedActionItem]) async throws {
        let taskRepository = DIContainer.shared.taskRepository
        let existingTasks = try await taskRepository.getTasksForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            var taskToUpdate: EventTask?
            if !item.existingItemId.isEmpty {
                taskToUpdate = existingTasks.first(where: { $0.id == item.existingItemId })
            }
            if taskToUpdate == nil {
                taskToUpdate = existingTasks.first(where: {
                    $0.title.lowercased().contains(item.title.lowercased()) ||
                    item.title.lowercased().contains($0.title.lowercased())
                })
            }

            if var task = taskToUpdate {
                print("✏️ [AIChat] Updating task: \(task.title)")
                if !item.newTitle.isEmpty {
                    task.title = item.newTitle
                }
                if !item.newDescription.isEmpty {
                    task.description = item.newDescription
                }
                try await taskRepository.updateTask(task)
            } else {
                print("⚠️ [AIChat] Could not find task to update: \(item.title)")
            }
        }
    }

    private func updateAgendaFromAction(_ items: [SuggestedActionItem]) async throws {
        let agendaRepository = DIContainer.shared.agendaRepository
        let existingAgenda = try await agendaRepository.getAgendaForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            var itemToUpdate: AgendaItem?
            if !item.existingItemId.isEmpty {
                itemToUpdate = existingAgenda.first(where: { $0.id == item.existingItemId })
            }
            if itemToUpdate == nil {
                itemToUpdate = existingAgenda.first(where: {
                    $0.title.lowercased().contains(item.title.lowercased()) ||
                    item.title.lowercased().contains($0.title.lowercased())
                })
            }

            if var agendaItem = itemToUpdate {
                print("✏️ [AIChat] Updating agenda: \(agendaItem.title)")
                if !item.newTitle.isEmpty {
                    agendaItem.title = item.newTitle
                }
                if !item.newDescription.isEmpty {
                    agendaItem.description = item.newDescription
                }
                try await agendaRepository.updateAgendaItem(agendaItem)
            } else {
                print("⚠️ [AIChat] Could not find agenda item to update: \(item.title)")
            }
        }
    }

    private func updateExpensesFromAction(_ items: [SuggestedActionItem]) async throws {
        let expenseRepository = DIContainer.shared.expenseRepository
        let existingExpenses = try await expenseRepository.getExpensesForEvent(eventId: event.id)

        for item in items {
            // First try by existingItemId, then fall back to title match
            var expenseToUpdate: Expense?
            if !item.existingItemId.isEmpty {
                expenseToUpdate = existingExpenses.first(where: { $0.id == item.existingItemId })
            }
            if expenseToUpdate == nil {
                expenseToUpdate = existingExpenses.first(where: {
                    $0.title.lowercased().contains(item.title.lowercased()) ||
                    item.title.lowercased().contains($0.title.lowercased())
                })
            }

            if var expense = expenseToUpdate {
                print("✏️ [AIChat] Updating expense: \(expense.title)")
                if !item.newTitle.isEmpty {
                    expense.title = item.newTitle
                }
                if !item.newDescription.isEmpty {
                    expense.description = item.newDescription
                }
                try await expenseRepository.updateExpense(expense)
            } else {
                print("⚠️ [AIChat] Could not find expense to update: \(item.title)")
            }
        }
    }

    private func updateBudgetFromAction(_ items: [SuggestedActionItem]) async throws {
        guard let item = items.first, item.amount > 0 else { return }
        let amount = Double(item.amount)
        _ = try await grpcClient.upsertEventBudget(
            eventId: event.id,
            plannedBudget: amount
        )
        print("💰 [AIChat] Updated budget to \(amount)")
    }

    private func generateChecklistForTopic(_ topic: AITopicType) async {
        defer { isTyping = false }

        do {
            let result = try await grpcClient.generateTopicChecklist(
                eventId: event.id,
                topic: topic.protoTopic
            )

            // Track last topic for context-aware hints
            lastTopic = topic.protoTopic

            let aiMessage = AIChatMessage(from: result.message)
            messages.append(aiMessage)
        } catch {
            self.error = error.localizedDescription
            // Add error message to chat
            let errorMessage = AIChatMessage(
                content: "Sorry, I couldn't generate a checklist for that topic. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
        }
    }

    func toggleChecklistItem(messageId: String, itemId: String) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }),
              var checklist = messages[messageIndex].checklist,
              let itemIndex = checklist.items.firstIndex(where: { $0.id == itemId }) else {
            return
        }

        // Optimistic update
        let newCheckedState = !checklist.items[itemIndex].isChecked
        checklist.items[itemIndex].isChecked = newCheckedState
        messages[messageIndex].checklist = checklist

        // Sync with backend
        Task {
            do {
                try await grpcClient.updateChecklistItem(
                    eventId: event.id,
                    checklistId: checklist.id,
                    itemId: itemId,
                    isChecked: newCheckedState
                )
            } catch {
                // Rollback on failure
                if var revertChecklist = messages[messageIndex].checklist,
                   let revertIndex = revertChecklist.items.firstIndex(where: { $0.id == itemId }) {
                    revertChecklist.items[revertIndex].isChecked = !newCheckedState
                    messages[messageIndex].checklist = revertChecklist
                }
            }
        }
    }

    func toggleSaveConversation() {
        guard let convId = conversationId else { return }

        let wasSaved = isConversationSaved

        // Optimistic update
        isConversationSaved.toggle()

        Task {
            do {
                if wasSaved {
                    try await grpcClient.unsaveConversation(eventId: event.id, conversationId: convId)
                } else {
                    _ = try await grpcClient.saveConversation(eventId: event.id, conversationId: convId)
                }
                // Refresh saved conversations from backend
                await loadSavedConversations()
            } catch {
                // Rollback on failure
                isConversationSaved = wasSaved
            }
        }
    }

    /// Check if current conversation is saved
    @Published var isConversationSaved: Bool = false

    /// Check if conversation is saved after loading
    func checkIfConversationSaved() async {
        guard let convId = conversationId else {
            isConversationSaved = false
            return
        }

        do {
            let conversations = try await grpcClient.getSavedConversations(eventId: event.id)
            isConversationSaved = conversations.contains { $0.conversationID == convId }
        } catch {
            isConversationSaved = false
        }
    }

    /// Find the message ID that contains a specific checklist
    func messageIdForChecklist(_ checklistId: String) -> String? {
        messages.first { $0.checklist?.id == checklistId }?.id
    }

    /// Scroll to a message with a specific checklist
    /// Returns true if the message was found and scroll was triggered
    @discardableResult
    func scrollToChecklist(_ checklistId: String) -> Bool {
        if let messageId = messageIdForChecklist(checklistId) {
            scrollToMessageId = messageId
            return true
        }
        return false
    }

    /// Check if a checklist's message exists in current chat
    func hasMessageForChecklist(_ checklistId: String) -> Bool {
        messageIdForChecklist(checklistId) != nil
    }

    /// Load a specific conversation from backend
    /// Used when viewing a saved conversation from the saved page
    func loadConversation(conversationId: String) async {
        // Load chat history filtered by conversation
        do {
            let (protoMessages, _) = try await grpcClient.getChatHistory(
                eventId: event.id,
                conversationId: conversationId
            )

            // Replace current messages with loaded history
            let loadedMessages = protoMessages.map { AIChatMessage(from: $0) }
            messages = loadedMessages

            // Set conversationId for continuity
            self.conversationId = conversationId

            // Check if this conversation is saved
            await checkIfConversationSaved()

            // Small delay to let view update, then scroll to bottom
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            if let lastMessage = messages.last {
                scrollToMessageId = lastMessage.id
            }
        } catch {
            // Error handled silently
        }
    }

    /// Load a specific conversation from backend and scroll to a checklist
    /// Used when viewing a saved checklist from a previous session
    func loadConversationAndScrollTo(conversationId: String?, checklistId: String) async {
        // Load chat history filtered by conversation
        do {
            let (protoMessages, _) = try await grpcClient.getChatHistory(
                eventId: event.id,
                conversationId: conversationId
            )

            // Replace current messages with loaded history
            let loadedMessages = protoMessages.map { AIChatMessage(from: $0) }
            messages = loadedMessages

            // Set conversationId from first message if available
            if let firstMessage = protoMessages.first, !firstMessage.conversationID.isEmpty {
                self.conversationId = firstMessage.conversationID
            }

            // Small delay to let view update, then scroll
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            scrollToChecklist(checklistId)
        } catch {
            // Error handled silently
        }
    }

    /// Unsave a conversation by ID (from saved page)
    func unsaveConversation(_ conversationId: String) {
        Task {
            do {
                try await grpcClient.unsaveConversation(eventId: event.id, conversationId: conversationId)
                // Refresh saved conversations
                await loadSavedConversations()
            } catch {
                // Error handled silently
            }
        }
    }
}
