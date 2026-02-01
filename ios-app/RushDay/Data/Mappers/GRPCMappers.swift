import Foundation
import SwiftProtobuf

// MARK: - Event Mapper (gRPC → Domain)

extension Event {
    /// Creates an Event domain entity from a gRPC Event response
    init(from grpcEvent: Rushday_V1_Event) {
        self.id = grpcEvent.id
        self.name = grpcEvent.name
        self.startDate = grpcEvent.date.date
        self.createAt = grpcEvent.hasCreatedAt ? grpcEvent.createdAt.date : Date()
        self.eventTypeId = grpcEvent.hasType ? grpcEvent.type : EventType.custom.rawValue
        self.ownerId = grpcEvent.userID

        // Owner name from backend (dynamic, updates when owner changes their name)
        self.ownerName = grpcEvent.hasOwnerName ? grpcEvent.ownerName : nil

        // Optional fields
        self.isAllDay = grpcEvent.isAllDay
        self.isMovedToDraft = grpcEvent.isDraft
        self.endDate = grpcEvent.hasEndDate ? grpcEvent.endDate.date : nil
        self.venue = grpcEvent.hasVenue ? grpcEvent.venue : nil
        self.customIdea = grpcEvent.hasCustomIdea ? grpcEvent.customIdea : nil
        self.themeIdea = grpcEvent.hasThemeIdea ? grpcEvent.themeIdea : nil
        // Fix: Don't rely on hasImage, directly check if image string is non-empty
        let imageValue = grpcEvent.image
        self.coverImage = imageValue.isEmpty ? nil : imageValue
        self.inviteMessage = grpcEvent.hasInviteMessage ? grpcEvent.inviteMessage : nil
        self.updatedAt = grpcEvent.hasUpdatedAt ? grpcEvent.updatedAt.date : nil

        // Co-hosts (shared users)
        self.shared = grpcEvent.shared.map { SharedUser(from: $0) }

    }
}

// MARK: - SharedUser Mapper (gRPC → Domain)

extension SharedUser {
    /// Creates a SharedUser domain entity from a gRPC SharedUser response
    init(from grpcShared: Rushday_V1_SharedUser) {
        self.name = grpcShared.name
        self.accepted = grpcShared.accepted
        self.userId = grpcShared.hasUserID ? grpcShared.userID : nil
        self.secret = grpcShared.secret
        self.accessRole = AccessRole(rawValue: grpcShared.accessRole) ?? .admin
    }
}

// MARK: - Google Protobuf Timestamp Extension

extension Google_Protobuf_Timestamp {
    /// Converts to Swift Date
    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000)
    }

    /// Creates from Swift Date
    init(date: Date) {
        self.init()
        let interval = date.timeIntervalSince1970
        self.seconds = Int64(interval)
        self.nanos = Int32((interval - Double(self.seconds)) * 1_000_000_000)
    }
}

// MARK: - ListEventsResponse Extension

extension Rushday_V1_ListEventsResponse {
    /// Maps all events from the response to domain events
    func toDomainEvents() -> [Event] {
        return events.map { Event(from: $0) }
    }
}

// MARK: - StreamEventsResponse Extension

extension Rushday_V1_StreamEventsResponse {
    /// Maps all events from the streaming response to domain events
    func toDomainEvents() -> [Event] {
        return events.map { Event(from: $0) }
    }
}

// MARK: - User Mapper (gRPC → Domain)

extension User {
    /// Creates a User domain entity from a gRPC User response
    init(from grpcUser: Rushday_V1_User) {
        self.id = grpcUser.id
        self.name = grpcUser.name
        self.email = grpcUser.email
        // Fix: Don't rely on hasAvatar, directly check if avatar string is non-empty
        let avatarValue = grpcUser.avatar
        self.photoUrl = avatarValue.isEmpty ? nil : avatarValue
        self.currency = grpcUser.currency.isEmpty ? "USD" : grpcUser.currency
        self.isPremium = grpcUser.isPremium
        self.createAt = grpcUser.hasCreatedAt ? grpcUser.createdAt.date : Date()
        self.updateAt = grpcUser.hasUpdatedAt ? grpcUser.updatedAt.date : nil
        self.events = []  // Not included in gRPC response

        // Map notification preferences from gRPC
        if grpcUser.hasNotificationPreferences {
            self.notificationConfiguration = NotificationConfiguration(from: grpcUser.notificationPreferences)
        } else {
            self.notificationConfiguration = nil
        }

    }
}

// MARK: - Task Mapper (gRPC → Domain)

extension EventTask {
    /// Creates an EventTask domain entity from a gRPC Task response
    init(from grpcTask: Rushday_V1_Task) {
        self.id = grpcTask.id
        self.eventId = grpcTask.eventID
        self.title = grpcTask.name
        self.description = grpcTask.hasNotes ? grpcTask.notes : nil
        self.status = grpcTask.isDone ? .completed : .pending
        self.priority = .medium  // gRPC doesn't have priority, default to medium
        self.dueDate = grpcTask.hasNotification ? grpcTask.notification.date : nil
        self.assignedTo = []  // Not in gRPC model
        self.category = nil
        self.estimatedCost = nil
        self.actualCost = nil
        self.attachments = []
        self.createdBy = ""  // Not in gRPC model
        self.createdAt = grpcTask.hasCreatedAt ? grpcTask.createdAt.date : Date()
        self.updatedAt = grpcTask.hasUpdatedAt ? grpcTask.updatedAt.date : Date()
        self.completedAt = grpcTask.isDone ? (grpcTask.hasUpdatedAt ? grpcTask.updatedAt.date : Date()) : nil
        self.order = Int(grpcTask.orderNumber)
    }
}

// MARK: - Guest Mapper (gRPC → Domain)

extension Guest {
    /// Creates a Guest domain entity from a gRPC Guest response
    init(from grpcGuest: Rushday_V1_Guest) {
        self.id = grpcGuest.id
        self.eventId = grpcGuest.eventID
        self.userId = nil
        self.contactId = nil
        self.name = grpcGuest.name
        // Contact info is nested in grpcGuest.contact
        self.email = grpcGuest.hasContact && grpcGuest.contact.hasEmail ? grpcGuest.contact.email : nil
        self.phoneNumber = grpcGuest.hasContact && grpcGuest.contact.hasPhoneNumber ? grpcGuest.contact.phoneNumber : nil
        self.photoURL = nil
        self.rsvpStatus = RSVPStatus(from: grpcGuest.status)
        self.role = .guest
        self.plusOnes = Int(grpcGuest.accompany)
        self.dietaryRestrictions = []
        self.notes = grpcGuest.hasNotes ? grpcGuest.notes : nil
        self.invitedAt = Date()
        self.respondedAt = nil
        self.createdAt = grpcGuest.hasCreatedAt ? grpcGuest.createdAt.date : Date()
        self.updatedAt = grpcGuest.hasUpdatedAt ? grpcGuest.updatedAt.date : Date()
    }
}

extension RSVPStatus {
    init(from grpcStatus: Rushday_V1_GuestStatus) {
        switch grpcStatus {
        case .accepted:
            self = .confirmed
        case .declined:
            self = .declined
        case .invited:
            self = .pending
        case .notInvited:
            self = .notInvited
        case .unspecified, .UNRECOGNIZED:
            self = .pending
        }
    }

    var toGRPC: Rushday_V1_GuestStatus {
        switch self {
        case .confirmed:
            return .accepted
        case .declined:
            return .declined
        case .pending:
            return .invited
        case .notInvited:
            return .notInvited
        case .maybe:
            return .invited
        }
    }
}

extension Guest {
    /// Creates a gRPC CreateGuestRequest from domain Guest
    func toCreateRequest() -> Rushday_V1_CreateGuestRequest {
        var request = Rushday_V1_CreateGuestRequest()
        if let eventId = eventId {
            request.eventID = eventId
        }
        request.name = name
        if email != nil || phoneNumber != nil {
            var contact = Rushday_V1_GuestContact()
            if let email = email {
                contact.email = email
            }
            if let phone = phoneNumber {
                contact.phoneNumber = phone
            }
            request.contact = contact
        }
        request.status = rsvpStatus.toGRPC
        request.accompany = Int32(plusOnes)
        return request
    }

    /// Creates a gRPC UpdateGuestRequest from domain Guest
    func toUpdateRequest() -> Rushday_V1_UpdateGuestRequest {
        var request = Rushday_V1_UpdateGuestRequest()
        request.id = id
        request.name = name
        if email != nil || phoneNumber != nil {
            var contact = Rushday_V1_GuestContact()
            if let email = email {
                contact.email = email
            }
            if let phone = phoneNumber {
                contact.phoneNumber = phone
            }
            request.contact = contact
        }
        request.status = rsvpStatus.toGRPC
        request.accompany = Int32(plusOnes)
        return request
    }
}

// MARK: - Agenda Mapper (gRPC → Domain)

extension AgendaItem {
    /// Creates an AgendaItem domain entity from a gRPC Agenda response
    init(from grpcAgenda: Rushday_V1_Agenda) {
        self.id = grpcAgenda.id
        self.eventId = grpcAgenda.eventID
        self.title = grpcAgenda.title
        self.description = grpcAgenda.hasNotes ? grpcAgenda.notes : nil
        self.startTime = grpcAgenda.hasStartTime ? grpcAgenda.startTime.date : Date()
        self.endTime = grpcAgenda.hasEndTime ? grpcAgenda.endTime.date : nil
        self.location = nil
        self.speakerId = nil
        self.speakerName = nil
        self.isBreak = false
        self.order = 0
        self.createdAt = grpcAgenda.hasCreatedAt ? grpcAgenda.createdAt.date : Date()
        self.updatedAt = grpcAgenda.hasUpdatedAt ? grpcAgenda.updatedAt.date : Date()
    }
}

// MARK: - Expense Mapper (gRPC → Domain)
// Note: gRPC uses "Budget" terminology, Domain uses "Expense"

extension Expense {
    /// Creates an Expense domain entity from a gRPC Budget response
    init(from grpcBudget: Rushday_V1_Budget) {
        self.id = grpcBudget.id
        self.eventId = grpcBudget.eventID
        self.title = grpcBudget.title
        self.description = nil
        self.category = .other
        self.amount = Double(grpcBudget.totalAmount) / 100.0  // Cents to dollars
        self.paidAmount = 0
        self.currency = "USD"
        self.paymentStatus = .pending
        self.vendorId = nil
        self.vendorName = nil
        self.dueDate = grpcBudget.hasDate ? grpcBudget.date.date : nil
        self.paidDate = nil
        self.receiptURL = nil
        self.notes = grpcBudget.hasNotes ? grpcBudget.notes : nil
        self.createdBy = ""
        self.createdAt = grpcBudget.hasCreatedAt ? grpcBudget.createdAt.date : Date()
        self.updatedAt = grpcBudget.hasUpdatedAt ? grpcBudget.updatedAt.date : Date()
    }
}

// MARK: - AI Event Planner Mappers

extension GeneratedPlanSummary {
    /// Creates a GeneratedPlanSummary from a gRPC EventPlanSummary response
    init(from grpcSummary: Rushday_V1_EventPlanSummary) {
        self.id = grpcSummary.id
        self.title = grpcSummary.title
        self.description = grpcSummary.description_p
        self.tier = PlanTier(from: grpcSummary.tier)
        self.style = GeneratedPlan.PlanStyle(from: grpcSummary.style)
        self.matchScore = Int(grpcSummary.matchScore)
        self.estimatedBudgetMin = Int(grpcSummary.estimatedBudget.minAmount)
        self.estimatedBudgetMax = Int(grpcSummary.estimatedBudget.maxAmount)
        self.highlights = grpcSummary.highlights
        self.venueDescription = grpcSummary.venueDescription.isEmpty ? nil : grpcSummary.venueDescription
        self.cateringDescription = grpcSummary.cateringDescription.isEmpty ? nil : grpcSummary.cateringDescription
        self.entertainmentDescription = grpcSummary.entertainmentDescription.isEmpty ? nil : grpcSummary.entertainmentDescription
    }
}

extension GeneratedPlan {
    /// Creates a GeneratedPlan domain entity from a gRPC EventPlan response
    init(from grpcPlan: Rushday_V1_EventPlan) {
        self.id = grpcPlan.id
        self.title = grpcPlan.title
        self.description = grpcPlan.description_p
        self.style = PlanStyle(from: grpcPlan.style)
        self.tier = PlanTier(from: grpcPlan.tier)
        self.matchScore = Int(grpcPlan.matchScore)

        // Budget - store both range and average cost
        if grpcPlan.hasEstimatedBudget {
            let minAmount = Int(grpcPlan.estimatedBudget.minAmount)
            let maxAmount = Int(grpcPlan.estimatedBudget.maxAmount)
            self.estimatedBudgetMin = minAmount
            self.estimatedBudgetMax = maxAmount
            self.estimatedCost = (minAmount + maxAmount) / 2
        } else {
            self.estimatedBudgetMin = 0
            self.estimatedBudgetMax = 0
            self.estimatedCost = 0
        }

        self.highlights = grpcPlan.highlights

        // Descriptions
        self.venueDescription = grpcPlan.venueDescription.isEmpty ? nil : grpcPlan.venueDescription
        self.cateringDescription = grpcPlan.cateringDescription.isEmpty ? nil : grpcPlan.cateringDescription
        self.entertainmentDescription = grpcPlan.entertainmentDescription.isEmpty ? nil : grpcPlan.entertainmentDescription

        // Vendors
        if !grpcPlan.suggestedVendors.isEmpty {
            self.vendors = grpcPlan.suggestedVendors.map { PlanVendor(from: $0) }
        } else {
            self.vendors = nil
        }

        // Timeline (from suggested agenda)
        if !grpcPlan.suggestedAgenda.isEmpty {
            self.timeline = grpcPlan.suggestedAgenda.map { PlanTimelineItem(from: $0) }
        } else {
            self.timeline = nil
        }

        // Suggested tasks
        if !grpcPlan.suggestedTasks.isEmpty {
            self.suggestedTasks = grpcPlan.suggestedTasks.map { PlanTask(from: $0) }
        } else {
            self.suggestedTasks = nil
        }
    }

    /// Creates a GeneratedPlan from a gRPC EventPlanSummary that includes full details
    /// Used when include_tasks/include_agenda/include_vendors flags are set in the request
    init(fromSummary grpcSummary: Rushday_V1_EventPlanSummary) {
        self.id = grpcSummary.id
        self.title = grpcSummary.title
        self.description = grpcSummary.description_p
        self.style = PlanStyle(from: grpcSummary.style)
        self.tier = PlanTier(from: grpcSummary.tier)
        self.matchScore = Int(grpcSummary.matchScore)

        // Budget - store both range and average cost
        if grpcSummary.hasEstimatedBudget {
            let minAmount = Int(grpcSummary.estimatedBudget.minAmount)
            let maxAmount = Int(grpcSummary.estimatedBudget.maxAmount)
            self.estimatedBudgetMin = minAmount
            self.estimatedBudgetMax = maxAmount
            self.estimatedCost = (minAmount + maxAmount) / 2
        } else {
            self.estimatedBudgetMin = 0
            self.estimatedBudgetMax = 0
            self.estimatedCost = 0
        }

        self.highlights = grpcSummary.highlights

        // Descriptions
        self.venueDescription = grpcSummary.venueDescription.isEmpty ? nil : grpcSummary.venueDescription
        self.cateringDescription = grpcSummary.cateringDescription.isEmpty ? nil : grpcSummary.cateringDescription
        self.entertainmentDescription = grpcSummary.entertainmentDescription.isEmpty ? nil : grpcSummary.entertainmentDescription

        // Vendors (optional, populated when include_vendors=true)
        if !grpcSummary.suggestedVendors.isEmpty {
            self.vendors = grpcSummary.suggestedVendors.map { PlanVendor(from: $0) }
        } else {
            self.vendors = nil
        }

        // Timeline from suggested agenda (optional, populated when include_agenda=true)
        if !grpcSummary.suggestedAgenda.isEmpty {
            self.timeline = grpcSummary.suggestedAgenda.map { PlanTimelineItem(from: $0) }
        } else {
            self.timeline = nil
        }

        // Suggested tasks (optional, populated when include_tasks=true)
        if !grpcSummary.suggestedTasks.isEmpty {
            self.suggestedTasks = grpcSummary.suggestedTasks.map { PlanTask(from: $0) }
        } else {
            self.suggestedTasks = nil
        }
    }
}

extension GeneratedPlan.PlanStyle {
    init(from grpcStyle: Rushday_V1_PlanStyle) {
        switch grpcStyle {
        case .classic:
            self = .classic
        case .modern:
            self = .modern
        case .natural:
            self = .natural
        case .luxury:
            self = .luxury
        case .custom, .unspecified, .UNRECOGNIZED:
            self = .custom
        }
    }

    var toGRPC: Rushday_V1_PlanStyle {
        switch self {
        case .classic: return .classic
        case .modern: return .modern
        case .natural: return .natural
        case .luxury: return .luxury
        case .custom: return .custom
        }
    }
}

extension PlanTier {
    init(from grpcTier: Rushday_V1_PlanTier) {
        switch grpcTier {
        case .aiRecommended:
            self = .aiRecommended
        case .popular:
            self = .popular
        case .standard, .unspecified, .UNRECOGNIZED:
            self = .standard
        }
    }

    var toGRPC: Rushday_V1_PlanTier {
        switch self {
        case .aiRecommended: return .aiRecommended
        case .popular: return .popular
        case .standard: return .standard
        }
    }
}

extension PlanVendor {
    init(from grpcVendor: Rushday_V1_SuggestedVendor) {
        self.id = grpcVendor.id
        self.name = grpcVendor.name
        self.category = grpcVendor.category
        self.price = grpcVendor.estimatedCost > 0 ? Int(grpcVendor.estimatedCost) : nil
        self.rating = grpcVendor.rating > 0 ? grpcVendor.rating : nil
        self.imageUrl = grpcVendor.imageURL.isEmpty ? nil : grpcVendor.imageURL
    }
}

extension PlanTimelineItem {
    init(from grpcAgenda: Rushday_V1_SuggestedAgendaItem) {
        self.id = grpcAgenda.id
        self.title = grpcAgenda.title
        self.description = grpcAgenda.description_p.isEmpty ? nil : grpcAgenda.description_p

        // Format time from timestamp
        if grpcAgenda.hasStartTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            self.time = formatter.string(from: grpcAgenda.startTime.date)
        } else {
            self.time = ""
        }

        self.duration = grpcAgenda.durationMinutes > 0 ? Int(grpcAgenda.durationMinutes) : nil
    }
}

extension PlanTask {
    init(from grpcTask: Rushday_V1_SuggestedTask) {
        self.id = grpcTask.id
        self.title = grpcTask.title
        self.description = grpcTask.description_p.isEmpty ? nil : grpcTask.description_p
        self.daysBeforeEvent = grpcTask.daysBeforeEvent > 0 ? Int(grpcTask.daysBeforeEvent) : nil
        self.priority = grpcTask.priority.isEmpty ? nil : grpcTask.priority
        self.category = grpcTask.category.isEmpty ? nil : grpcTask.category
    }
}

// MARK: - AI Planner Request Builders

extension AIEventType {
    var toGRPC: Rushday_V1_AIEventType {
        switch self {
        case .birthday: return .birthday
        case .wedding: return .wedding
        case .business: return .business
        case .babyShower: return .babyShower
        case .graduation: return .graduation
        case .engagement: return .engagement
        case .anniversary: return .anniversary
        case .other: return .other
        }
    }
}

extension GuestCountRange {
    var toGRPC: Rushday_V1_GuestCountRange {
        switch self {
        case .intimate: return .intimate
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .massive: return .massive
        }
    }
}

extension AIVenueType {
    var toGRPC: Rushday_V1_VenueType {
        switch self {
        case .indoorVenue: return .indoorVenue
        case .outdoorSpace: return .outdoorSpace
        case .atHome: return .atHome
        case .hotel: return .hotel
        }
    }
}

extension BudgetTier {
    var toGRPC: Rushday_V1_BudgetTier {
        switch self {
        case .economy: return .economy
        case .standard: return .standard
        case .premium: return .premium
        case .luxury: return .luxury
        }
    }
}

extension ServiceType {
    var toGRPC: Rushday_V1_ServiceType {
        switch self {
        case .catering: return .catering
        case .decoration: return .decoration
        case .entertainment: return .entertainment
        case .photoVideo: return .photoVideo
        case .invitations: return .invitations
        case .transport: return .transport
        }
    }
}

// MARK: - Generate Event Plans Request Builder

extension PendingEventData {
    /// Builds a gRPC GenerateEventPlansRequest from PendingEventData
    /// - Parameters:
    ///   - adjustmentText: Optional adjustment text from results page
    ///   - includeTasks: If true, includes tasks in response (default: true for authenticated users)
    ///   - includeAgenda: If true, includes agenda in response (default: false - generated later at event details)
    ///   - includeVendors: If true, includes vendors/expenses in response (default: false - generated later at event details)
    func toGRPCRequest(
        adjustmentText: String? = nil,
        includeTasks: Bool = false,
        includeAgenda: Bool = false,
        includeVendors: Bool = false,
        targetPlanStyle: Rushday_V1_TargetPlanStyle = .unspecified
    ) -> Rushday_V1_GenerateEventPlansRequest {
        var request = Rushday_V1_GenerateEventPlansRequest()

        // Step 1: Event Type
        if let eventType = eventType {
            request.eventType = eventType.toGRPC
        }
        if let customType = customEventType, !customType.isEmpty {
            request.customEventType = customType
        }

        // Step 2: Guest Count
        if let guestRange = guestRange {
            request.guestRange = guestRange.toGRPC
        }
        if let customCount = customGuestCount {
            request.customGuestCount = Int32(customCount)
        }

        // Step 3: Event Details
        if let name = eventName, !name.isEmpty {
            request.eventName = name
        }
        if let startDate = eventStartDate {
            request.startDate = Google_Protobuf_Timestamp(date: startDate)
        }
        if let endDate = eventEndDate {
            request.endDate = Google_Protobuf_Timestamp(date: endDate)
        }
        if let venue = eventVenue, !venue.isEmpty {
            request.venueLocation = venue
        }

        // Step 4: Venue Type
        if let venueType = venueType {
            request.venueType = venueType.toGRPC
        }
        if let customVenue = customVenueName, !customVenue.isEmpty {
            request.customVenueName = customVenue
        }
        request.venueSkipped = venueSkipped

        // Step 5: Budget
        if let budgetTier = budgetTier {
            request.budgetTier = budgetTier.toGRPC
        }
        if let customAmount = customBudgetAmount {
            request.customBudgetAmount = Int32(customAmount)
        }

        // Step 6: Services
        request.selectedServices = selectedServices.map { $0.toGRPC }
        if let customSvc = customService, !customSvc.isEmpty {
            request.customService = customSvc
        }
        request.servicesSkipped = servicesSkipped

        // Step 7: Preferences
        if let prefs = preferencesText, !prefs.isEmpty {
            request.preferencesText = prefs
        }
        request.selectedTags = selectedTags
        request.preferencesSkipped = preferencesSkipped

        // Additional adjustment from results page
        if let adjustment = adjustmentText, !adjustment.isEmpty {
            request.adjustmentText = adjustment
        }

        // Include details flags - tasks only for initial generation, agenda/vendors generated later
        request.includeTasks = includeTasks
        request.includeAgenda = includeAgenda
        request.includeVendors = includeVendors

        // Target plan style for parallel single-plan generation
        request.targetPlanStyle = targetPlanStyle

        return request
    }
}

// MARK: - Response Extension

extension Rushday_V1_GenerateEventPlansResponse {
    /// Maps all plans from the response to domain plans
    func toDomainPlans() -> [GeneratedPlan] {
        return plans.map { GeneratedPlan(from: $0) }
    }
}
