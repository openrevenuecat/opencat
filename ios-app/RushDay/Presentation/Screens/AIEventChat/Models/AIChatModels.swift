import Foundation

// MARK: - AI Chat Models

/// Represents a tool execution made by the AI agent
struct ToolExecution: Identifiable, Equatable {
    let id: String
    let toolName: String
    let status: String  // "success", "error", "pending_approval"
    let summary: String

    init(
        id: String = UUID().uuidString,
        toolName: String,
        status: String,
        summary: String
    ) {
        self.id = id
        self.toolName = toolName
        self.status = status
        self.summary = summary
    }

    /// Initialize from proto ToolExecution
    init(from proto: Rushday_V1_ToolExecution) {
        self.id = UUID().uuidString
        self.toolName = proto.toolName
        self.status = proto.status
        self.summary = proto.summary
    }

    /// Icon for the tool based on name
    var icon: String {
        switch toolName {
        case "get_tasks": return "checklist"
        case "get_agenda": return "calendar"
        case "get_expenses": return "dollarsign.circle"
        case "search_web": return "magnifyingglass"
        case "suggest_add_tasks", "suggest_remove_tasks": return "checklist"
        case "suggest_add_agenda", "suggest_remove_agenda": return "calendar.badge.plus"
        case "suggest_add_expenses", "suggest_remove_expenses": return "dollarsign.circle.fill"
        default: return "wrench"
        }
    }

    /// Whether the execution was successful
    var isSuccess: Bool {
        status == "success"
    }

    /// Whether the execution is pending user approval
    var isPendingApproval: Bool {
        status == "pending_approval"
    }

    /// Whether this is an error state
    var isError: Bool {
        status == "error"
    }

    /// Whether this tool is currently executing (in progress)
    var isInProgress: Bool {
        status == "in_progress"
    }
}

/// Represents a chat message in the AI conversation
struct AIChatMessage: Identifiable, Equatable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isSaved: Bool
    var checklist: AIChatChecklist?
    var suggestedAction: SuggestedAction?
    var actionApplied: Bool  // Track if user applied the suggested action
    var checklistTasksAdded: Bool  // Track if checklist items were added to tasks
    var toolExecutions: [ToolExecution]?  // Tool calls made during this response

    init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isSaved: Bool = false,
        checklist: AIChatChecklist? = nil,
        suggestedAction: SuggestedAction? = nil,
        actionApplied: Bool = false,
        checklistTasksAdded: Bool = false,
        toolExecutions: [ToolExecution]? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isSaved = isSaved
        self.checklist = checklist
        self.suggestedAction = suggestedAction
        self.actionApplied = actionApplied
        self.checklistTasksAdded = checklistTasksAdded
        self.toolExecutions = toolExecutions
    }

    /// Initialize from proto ChatMessage
    init(from proto: Rushday_V1_ChatMessage) {
        self.id = proto.id
        self.content = proto.content
        self.isUser = proto.role == .user
        self.timestamp = proto.hasCreatedAt ? proto.createdAt.date : Date()
        // Get saved state from checklist if present
        let checklist = proto.hasChecklist ? AIChatChecklist(from: proto.checklist) : nil
        self.checklist = checklist
        self.isSaved = checklist?.isSaved ?? false
        self.suggestedAction = nil  // Will be set separately from response
        self.actionApplied = false
        self.checklistTasksAdded = false
        self.toolExecutions = nil  // Will be set separately from response
    }

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.isSaved == rhs.isSaved &&
        lhs.actionApplied == rhs.actionApplied &&
        lhs.checklistTasksAdded == rhs.checklistTasksAdded
    }
}

/// Represents a checklist in an AI response
struct AIChatChecklist: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    var items: [AIChatChecklistItem]
    let topic: AITopicType?
    let isSaved: Bool
    let createdAt: Date
    let conversationId: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        items: [AIChatChecklistItem],
        topic: AITopicType? = nil,
        isSaved: Bool = false,
        createdAt: Date = Date(),
        conversationId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.items = items
        self.topic = topic
        self.isSaved = isSaved
        self.createdAt = createdAt
        self.conversationId = conversationId
    }

    /// Initialize from proto ChatChecklist
    init(from proto: Rushday_V1_ChatChecklist) {
        self.id = proto.id
        self.title = proto.title
        self.description = proto.description_p
        self.items = proto.items.map { AIChatChecklistItem(from: $0) }
        self.topic = AITopicType(from: proto.topic)
        self.isSaved = proto.isSaved
        self.createdAt = proto.hasCreatedAt ? proto.createdAt.date : Date()
        self.conversationId = proto.conversationID.isEmpty ? nil : proto.conversationID
    }
}

/// Represents a single checklist item
struct AIChatChecklistItem: Identifiable, Equatable {
    let id: String
    let text: String
    var isChecked: Bool

    init(
        id: String = UUID().uuidString,
        text: String,
        isChecked: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
    }

    /// Initialize from proto ChatChecklistItem
    init(from proto: Rushday_V1_ChatChecklistItem) {
        self.id = proto.id
        self.text = proto.text
        self.isChecked = proto.isChecked
    }
}

/// Topics that users can select for AI assistance
enum AITopicType: String, CaseIterable, Identifiable {
    case venue = "Venue Selection"
    case decor = "Decor Ideas"
    case catering = "Catering"
    case budget = "Budget"
    case music = "Music"
    case photoVideo = "Photo/Video"
    case entertainment = "Entertainment"
    case timeline = "Timeline"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .venue: return "mappin.and.ellipse"
        case .decor: return "sparkles"
        case .catering: return "fork.knife"
        case .budget: return "dollarsign.circle"
        case .music: return "music.note"
        case .photoVideo: return "camera"
        case .entertainment: return "theatermasks"
        case .timeline: return "calendar.badge.clock"
        }
    }

    var prompt: String {
        switch self {
        case .venue: return "Help me find the perfect venue"
        case .decor: return "Give me decoration ideas"
        case .catering: return "Suggest catering options"
        case .budget: return "Help me plan my budget"
        case .music: return "Recommend music and entertainment"
        case .photoVideo: return "Suggest photo and video options"
        case .entertainment: return "What entertainment should I have?"
        case .timeline: return "Help me create a timeline"
        }
    }

    /// Convert to proto ChatTopic
    var protoTopic: Rushday_V1_ChatTopic {
        switch self {
        case .venue: return .venue
        case .decor: return .decor
        case .catering: return .catering
        case .budget: return .budget
        case .music: return .music
        case .photoVideo: return .photoVideo
        case .entertainment: return .entertainment
        case .timeline: return .timeline
        }
    }

    /// Initialize from proto ChatTopic
    init?(from proto: Rushday_V1_ChatTopic) {
        switch proto {
        case .venue: self = .venue
        case .decor: self = .decor
        case .catering: self = .catering
        case .budget: self = .budget
        case .music: self = .music
        case .photoVideo: self = .photoVideo
        case .entertainment: self = .entertainment
        case .timeline: self = .timeline
        case .unspecified, .general, .invitations, .transport, .UNRECOGNIZED: return nil
        }
    }
}

/// Saved messages collection
struct AISavedMessages: Identifiable {
    let id: String
    let eventId: String
    var messages: [AIChatMessage]

    init(
        id: String = UUID().uuidString,
        eventId: String,
        messages: [AIChatMessage] = []
    ) {
        self.id = id
        self.eventId = eventId
        self.messages = messages
    }
}

// MARK: - Suggested Actions

/// Types of actions the AI can suggest
enum SuggestedActionType: String {
    case none = ""
    // Tasks
    case addTasks = "add_tasks"
    case removeTasks = "remove_tasks"
    case updateTasks = "update_tasks"
    // Agenda
    case addAgenda = "add_agenda"
    case removeAgenda = "remove_agenda"
    case updateAgenda = "update_agenda"
    // Expenses
    case addExpenses = "add_expenses"
    case removeExpenses = "remove_expenses"
    case updateExpenses = "update_expenses"
    // Budget
    case updateBudget = "update_budget"

    /// Initialize from proto enum
    init(from proto: Rushday_V1_SuggestedActionType) {
        switch proto {
        case .addTasks: self = .addTasks
        case .removeTasks: self = .removeTasks
        case .updateTasks: self = .updateTasks
        case .addAgenda: self = .addAgenda
        case .removeAgenda: self = .removeAgenda
        case .updateAgenda: self = .updateAgenda
        case .addExpenses: self = .addExpenses
        case .removeExpenses: self = .removeExpenses
        case .updateExpenses: self = .updateExpenses
        case .updateBudget: self = .updateBudget
        default: self = .none
        }
    }

    /// Whether this is an "add" type action
    var isAddAction: Bool {
        switch self {
        case .addTasks, .addAgenda, .addExpenses: return true
        default: return false
        }
    }

    /// Whether this is a "remove" type action
    var isRemoveAction: Bool {
        switch self {
        case .removeTasks, .removeAgenda, .removeExpenses: return true
        default: return false
        }
    }

    /// Whether this is an "update" type action
    var isUpdateAction: Bool {
        switch self {
        case .updateTasks, .updateAgenda, .updateExpenses: return true
        default: return false
        }
    }

    /// The target entity type (tasks, agenda, or expenses)
    var targetEntity: String {
        switch self {
        case .addTasks, .removeTasks, .updateTasks: return "tasks"
        case .addAgenda, .removeAgenda, .updateAgenda: return "agenda"
        case .addExpenses, .removeExpenses, .updateExpenses: return "expenses"
        case .updateBudget: return "budget"
        case .none: return ""
        }
    }
}

/// Item that can be added/removed/updated via suggested action
struct SuggestedActionItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let amount: Int64
    let startTime: String
    let durationMinutes: Int32
    // For update operations
    let existingItemId: String  // ID of existing item to update/remove
    let newTitle: String        // New title for update
    let newDescription: String  // New description for update

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        category: String = "",
        amount: Int64 = 0,
        startTime: String = "",
        durationMinutes: Int32 = 0,
        existingItemId: String = "",
        newTitle: String = "",
        newDescription: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.amount = amount
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.existingItemId = existingItemId
        self.newTitle = newTitle
        self.newDescription = newDescription
    }

    /// Initialize from proto
    init(from proto: Rushday_V1_SuggestedActionItem) {
        self.id = proto.id.isEmpty ? UUID().uuidString : proto.id
        self.title = proto.title
        self.description = proto.description_p
        self.category = proto.category
        self.amount = proto.amount
        self.startTime = proto.startTime
        self.durationMinutes = proto.durationMinutes
        self.existingItemId = proto.id  // The proto id field is the existing item id
        self.newTitle = proto.newTitle
        self.newDescription = proto.newDescription
    }
}

/// Suggested action the AI can offer
struct SuggestedAction {
    let actionType: SuggestedActionType
    let promptText: String
    let confirmButtonText: String
    let declineButtonText: String
    let items: [SuggestedActionItem]

    /// Check if this is a valid action
    var isValid: Bool {
        actionType != .none && !items.isEmpty
    }

    init(
        actionType: SuggestedActionType,
        promptText: String,
        confirmButtonText: String,
        declineButtonText: String = "No thanks",
        items: [SuggestedActionItem]
    ) {
        self.actionType = actionType
        self.promptText = promptText
        self.confirmButtonText = confirmButtonText
        self.declineButtonText = declineButtonText
        self.items = items
    }

    /// Initialize from proto
    init?(from proto: Rushday_V1_SuggestedAction) {
        let type = SuggestedActionType(from: proto.actionType)
        guard type != .none else { return nil }

        self.actionType = type
        self.promptText = proto.promptText
        self.confirmButtonText = proto.confirmButtonText
        self.declineButtonText = proto.declineButtonText.isEmpty ? "No thanks" : proto.declineButtonText
        self.items = proto.items.map { SuggestedActionItem(from: $0) }
    }
}

// MARK: - Saved Conversation

/// Represents a saved chat conversation
struct SavedConversation: Identifiable, Equatable {
    let id: String
    let eventId: String
    let conversationId: String
    let title: String
    let preview: String
    let messageCount: Int
    let createdAt: Date
    let savedAt: Date

    /// Initialize from proto
    init(from proto: Rushday_V1_SavedConversation) {
        self.id = proto.id
        self.eventId = proto.eventID
        self.conversationId = proto.conversationID
        self.title = proto.title
        self.preview = proto.preview
        self.messageCount = Int(proto.messageCount)
        self.createdAt = proto.createdAt.date
        self.savedAt = proto.savedAt.date
    }
}
