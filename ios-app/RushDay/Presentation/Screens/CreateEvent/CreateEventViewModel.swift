import SwiftUI
import SwiftProtobuf

// MARK: - Guest Count Options
enum GuestCountOption: String, CaseIterable, Identifiable {
    case lessThan10 = "less_than_10"
    case tenTo20 = "10_to_20"
    case twentyTo50 = "20_to_50"
    case fiftyTo100 = "50_to_100"
    case hundredTo200 = "100_to_200"
    case moreThan200 = "more_than_200"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .lessThan10: return "\(L10n.lessThan) 10"
        case .tenTo20: return "10 - 20"
        case .twentyTo50: return "20 - 50"
        case .fiftyTo100: return "50 - 100"
        case .hundredTo200: return "100 - 200"
        case .moreThan200: return "\(L10n.moreThan) 200"
        }
    }
}

// MARK: - Venue Option
enum VenueOption: String, CaseIterable, Identifiable {
    case home = "home"
    case restaurant = "restaurant"
    case hotel = "hotel"
    case outdoor = "outdoor"
    case office = "office"
    case venue = "venue"
    case custom = "custom"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .home: return L10n.venueHome
        case .restaurant: return L10n.venueRestaurant
        case .hotel: return L10n.venueHotel
        case .outdoor: return L10n.venueOutdoor
        case .office: return L10n.venueOffice
        case .venue: return L10n.venueEventHall
        case .custom: return L10n.venueOther
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .home: return L10n.venueHomeDesc
        case .restaurant: return L10n.venueRestaurantDesc
        case .hotel: return L10n.venueHotelDesc
        case .outdoor: return L10n.venueOutdoorDesc
        case .office: return L10n.venueOfficeDesc
        case .venue: return L10n.venueEventHallDesc
        case .custom: return L10n.venueOtherDesc
        }
    }
}

// MARK: - Service Option
struct ServiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    var isSelected: Bool = false

    @MainActor
    static var allServices: [ServiceOption] {
        [
            ServiceOption(id: "catering", name: L10n.serviceCatering),
            ServiceOption(id: "photography", name: L10n.servicePhotography),
            ServiceOption(id: "videography", name: L10n.serviceVideography),
            ServiceOption(id: "music_dj", name: L10n.serviceMusicDJ),
            ServiceOption(id: "decorations", name: L10n.serviceDecorations),
            ServiceOption(id: "flowers", name: L10n.serviceFlowers),
            ServiceOption(id: "cake", name: L10n.serviceCakeDesserts),
            ServiceOption(id: "transportation", name: L10n.serviceTransportation),
            ServiceOption(id: "entertainment", name: L10n.serviceEntertainment),
            ServiceOption(id: "invitations", name: L10n.serviceInvitations),
            ServiceOption(id: "rentals", name: L10n.serviceRentals),
            ServiceOption(id: "security", name: L10n.serviceSecurity),
        ]
    }
}

// MARK: - Currency
struct Currency: Identifiable, Hashable {
    let code: String
    let nameKey: String
    let symbol: String

    var id: String { code }

    @MainActor
    var name: String {
        switch nameKey {
        case "USD": return L10n.currencyUSDollar
        case "EUR": return L10n.currencyEuro
        case "GBP": return L10n.currencyBritishPound
        case "JPY": return L10n.currencyJapaneseYen
        case "AUD": return L10n.currencyAustralianDollar
        case "CAD": return L10n.currencyCanadianDollar
        case "CHF": return L10n.currencySwissFranc
        case "CNY": return L10n.currencyChineseYuan
        case "INR": return L10n.currencyIndianRupee
        case "RUB": return L10n.currencyRussianRuble
        case "UZS": return L10n.currencyUzbekSom
        default: return nameKey
        }
    }

    static let all: [Currency] = [
        Currency(code: "USD", nameKey: "USD", symbol: "$"),
        Currency(code: "EUR", nameKey: "EUR", symbol: "€"),
        Currency(code: "GBP", nameKey: "GBP", symbol: "£"),
        Currency(code: "JPY", nameKey: "JPY", symbol: "¥"),
        Currency(code: "AUD", nameKey: "AUD", symbol: "A$"),
        Currency(code: "CAD", nameKey: "CAD", symbol: "C$"),
        Currency(code: "CHF", nameKey: "CHF", symbol: "CHF"),
        Currency(code: "CNY", nameKey: "CNY", symbol: "¥"),
        Currency(code: "INR", nameKey: "INR", symbol: "₹"),
        Currency(code: "RUB", nameKey: "RUB", symbol: "₽"),
        Currency(code: "UZS", nameKey: "UZS", symbol: "so'm"),
    ]

    static let `default` = Currency(code: "USD", nameKey: "USD", symbol: "$")
}

// MARK: - View Model
@MainActor
class CreateEventViewModel: ObservableObject {
    // Step 1: Event Type
    @Published var selectedEventType: EventType?
    @Published var customTypeName: String = ""

    // Step 2: Name & Date
    @Published var eventName: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date?
    @Published var isAllDay: Bool = false
    @Published var hasSelectedDate: Bool = false
    @Published var venue: String = ""
    @Published var selectedCoverUrl: String?

    // Step 3: Venue Details
    @Published var selectedVenueOption: VenueOption?
    @Published var customVenueName: String = ""

    // Step 4: Guest Count
    @Published var selectedGuestCount: GuestCountOption?

    // Step 5: Budget
    @Published var budgetAmount: String = ""
    @Published var selectedCurrency: Currency = .default
    @Published var budgetMin: Int64?  // Budget range minimum (from tier)
    @Published var budgetMax: Int64?  // Budget range maximum (from tier)

    // Step 6: Services
    @Published var services: [ServiceOption] = ServiceOption.allServices
    @Published var customIdea: String = ""

    // Loading State
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var generationError: String?
    @Published var isGeneratingAgenda = false
    @Published var isGeneratingExpenses = false

    // Generated Content
    @Published var generatedResponse: EventAiResponse?
    @Published var selectedTasks: Set<String> = []

    // MARK: - Draft Event
    @Published var draftEventId: String?
    @Published var isCreatingDraft = false
    @Published var draftCreationError: String?

    let sessionId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

    @Published var createdEventId: String?

    private let eventGenerationService: EventGenerationServiceProtocol
    private let notificationRepository: NotificationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let authService: AuthServiceProtocol

    init() {
        self.eventGenerationService = EventGenerationService.shared
        self.notificationRepository = DIContainer.shared.notificationRepository
        self.userRepository = DIContainer.shared.userRepository
        self.authService = DIContainer.shared.authService
    }

    // MARK: - Computed Properties
    var selectedServicesNames: [String] {
        services.filter { $0.isSelected }.map { $0.name }
    }

    var formattedBudget: String? {
        guard let amount = Double(budgetAmount.replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return "Under \(selectedCurrency.symbol)\(formatted)"
        }
        return nil
    }

    var venueName: String {
        if selectedVenueOption == .custom {
            return customVenueName
        }
        return selectedVenueOption?.displayName ?? ""
    }

    var budgetDouble: Double? {
        Double(budgetAmount.replacingOccurrences(of: ",", with: ""))
    }

    // MARK: - Create Draft Event Silently
    func createDraftEventSilently() async {
        guard draftEventId == nil else {
            return
        }

        guard let eventType = selectedEventType else {
            return
        }

        isCreatingDraft = true
        draftCreationError = nil
        defer { isCreatingDraft = false }

        let guestCount: Int32
        switch selectedGuestCount {
        case .lessThan10: guestCount = 10
        case .tenTo20: guestCount = 20
        case .twentyTo50: guestCount = 50
        case .fiftyTo100: guestCount = 100
        case .hundredTo200: guestCount = 200
        case .moreThan200: guestCount = 300
        case nil: guestCount = 50
        }

        let budget = Int64(budgetDouble ?? 0)
        let coverImage = selectedCoverUrl ?? defaultCoverImageForEventType(eventType)

        do {
            let response = try await GRPCClientService.shared.createAIDraftEvent(
                name: eventName,
                eventType: eventType == .custom ? customTypeName : eventType.rawValue,
                date: startDate,
                budgetPlan: budget,
                guestsPlan: guestCount,
                coverImage: coverImage,
                sessionId: sessionId,
                budgetMin: budgetMin,
                budgetMax: budgetMax,
                venue: venueName.isEmpty ? nil : venueName
            )

            draftEventId = response.eventID
        } catch {
            draftCreationError = error.localizedDescription
        }
    }

    // MARK: - Claim Draft Event
    func claimDraftEventIfNeeded() async {
        guard let eventId = draftEventId else { return }

        do {
            _ = try await GRPCClientService.shared.claimDraftEvent(eventId: eventId, sessionId: sessionId)
        } catch {
            // Error handled silently
        }
    }

    // MARK: - Create Event with Generated Content
    func createEventWithGeneratedContent() async -> Bool {
        guard let generated = generatedResponse else {
            return false
        }

        guard let eventId = draftEventId else {
            generationError = "Please wait for draft event to be created"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        let grpc = GRPCClientService.shared

        do {
            await claimDraftEventIfNeeded()

            let publishResponse = try await grpc.publishAIDraftEvent(eventId: eventId, sessionId: sessionId)
            let publishedEventId = publishResponse.eventID

            self.createdEventId = publishedEventId

            await withTaskGroup(of: Void.self) { group in
                for generatedTask in generated.taskList where selectedTasks.contains(generatedTask.title) {
                    group.addTask {
                        do {
                            var request = Rushday_V1_CreateTaskRequest()
                            request.eventID = publishedEventId
                            request.name = generatedTask.title
                            _ = try await grpc.createTask(request)
                        } catch {
                            // Error handled silently
                        }
                    }
                }

                for agendaItem in generated.agenda {
                    group.addTask {
                        do {
                            var request = Rushday_V1_CreateAgendaRequest()
                            request.eventID = publishedEventId
                            request.title = agendaItem.activity
                            request.startTime = Google_Protobuf_Timestamp(date: agendaItem.startTime)
                            request.endTime = Google_Protobuf_Timestamp(date: agendaItem.endTime)
                            _ = try await grpc.createAgenda(request)
                        } catch {
                            // Error handled silently
                        }
                    }
                }

                for budgetItem in generated.budgetBreakdown {
                    group.addTask {
                        do {
                            var request = Rushday_V1_CreateBudgetRequest()
                            request.eventID = publishedEventId
                            request.title = budgetItem.category
                            request.totalAmount = Int64(budgetItem.estimatedCost)
                            _ = try await grpc.createBudget(request)
                        } catch {
                            // Error handled silently
                        }
                    }
                }

                await group.waitForAll()
            }

            await scheduleEventNotification(eventId: publishedEventId, eventName: eventName, eventDate: startDate)

            // Track event creation with AppsFlyer
            AppsFlyerService.shared.logEventCreated(eventType: selectedEventType?.rawValue ?? "unknown", isAIGenerated: true)

            return true
        } catch {
            generationError = error.localizedDescription
            return false
        }
    }

    // MARK: - Schedule Event Notification
    private func scheduleEventNotification(eventId: String, eventName: String, eventDate: Date) async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            let user = try await userRepository.getUser(id: userId)
            guard let config = user.notificationConfiguration else { return }

            guard let token = try await notificationRepository.getFcmToken() else { return }

            let event = Event(
                id: eventId,
                name: eventName,
                startDate: eventDate,
                eventTypeId: selectedEventType?.rawValue ?? "custom",
                ownerId: userId
            )

            if let request = EventNotificationHelper.buildCreateRequest(
                event: event,
                tokens: [token],
                userId: userId,
                config: config
            ) {
                _ = try await notificationRepository.createNotification(request)
            }
        } catch {
            // Error handled silently
        }
    }

    // MARK: - Generate Agenda
    /// Generates additional agenda items for the event, avoiding duplicates by passing existing titles
    func generateAgenda() async {
        guard let eventId = draftEventId else {
            generationError = "Please wait for draft event to be created"
            return
        }

        // Pass existing titles to the AI so it doesn't generate duplicates
        let existingTitles = generatedResponse?.agenda.map { $0.activity } ?? []

        isGeneratingAgenda = true
        generationError = nil
        defer { isGeneratingAgenda = false }

        do {
            let response = try await GRPCClientService.shared.generateAgenda(
                eventId: eventId,
                replaceExisting: false,
                existingTitles: existingTitles
            )

            if response.success {
                // Get existing activity titles to avoid duplicates
                let existingActivities = Set((generatedResponse?.agenda ?? []).map { $0.activity.lowercased() })

                // Map and deduplicate agenda items
                var seenActivities = existingActivities
                let newItems = response.agendaItems.compactMap { item -> GeneratedAgendaItem? in
                    let activity = formatAIText(item.title)
                    // Skip duplicates (check against existing and within new items)
                    guard !seenActivities.contains(activity.lowercased()) else { return nil }
                    seenActivities.insert(activity.lowercased())
                    return GeneratedAgendaItem(
                        startTime: item.startTime.date,
                        endTime: item.endTime.date,
                        activity: activity
                    )
                }

                if let currentResponse = generatedResponse {
                    // Append new unique items to existing agenda
                    let updatedAgenda = currentResponse.agenda + newItems
                    generatedResponse = EventAiResponse(
                        agenda: updatedAgenda,
                        taskList: currentResponse.taskList,
                        budgetBreakdown: currentResponse.budgetBreakdown,
                        totalBudget: currentResponse.totalBudget
                    )
                } else {
                    generatedResponse = EventAiResponse(
                        agenda: newItems,
                        taskList: [],
                        budgetBreakdown: [],
                        totalBudget: 0
                    )
                }
            } else {
                generationError = response.errorMessage.isEmpty ? "Failed to generate agenda" : response.errorMessage
            }
        } catch {
            generationError = error.localizedDescription
        }
    }

    // MARK: - Generate Expenses
    /// Generates or recalculates expenses for the event
    /// - Parameter recalculate: If true, replaces existing expenses. If false, only generates if no expenses exist.
    func generateExpenses(recalculate: Bool = false) async {
        guard let eventId = draftEventId else {
            generationError = "Please wait for draft event to be created"
            return
        }

        // Check if we already have expenses and this is not a recalculation
        let hasExistingExpenses = !(generatedResponse?.budgetBreakdown.isEmpty ?? true)
        let shouldReplace = recalculate && hasExistingExpenses

        // Get current agenda items to provide context for expense generation
        let currentAgendaItems = generatedResponse?.agenda.map { $0.activity } ?? []

        isGeneratingExpenses = true
        generationError = nil
        defer { isGeneratingExpenses = false }

        do {
            let response = try await GRPCClientService.shared.generateExpenses(
                eventId: eventId,
                replaceExisting: shouldReplace,
                currentAgendaItems: currentAgendaItems
            )

            if response.success {
                // Map and deduplicate expense items by category
                var seenCategories = Set<String>()
                let newItems = response.expenseItems.compactMap { item -> GeneratedBudgetItem? in
                    let category = formatAIText(item.category)
                    // Skip duplicates
                    guard !seenCategories.contains(category.lowercased()) else { return nil }
                    seenCategories.insert(category.lowercased())
                    return GeneratedBudgetItem(
                        category: category,
                        estimatedCost: Double(item.estimatedCost)
                    )
                }

                let totalBudget = newItems.reduce(0) { $0 + Int($1.estimatedCost) }

                if let currentResponse = generatedResponse {
                    // Replace expenses completely (for both initial and recalculate)
                    generatedResponse = EventAiResponse(
                        agenda: currentResponse.agenda,
                        taskList: currentResponse.taskList,
                        budgetBreakdown: newItems,
                        totalBudget: totalBudget
                    )
                } else {
                    generatedResponse = EventAiResponse(
                        agenda: [],
                        taskList: [],
                        budgetBreakdown: newItems,
                        totalBudget: totalBudget
                    )
                }
            } else {
                generationError = "Failed to generate expenses"
            }
        } catch {
            generationError = error.localizedDescription
        }
    }

    // MARK: - Helper Methods

    /// Formats AI-generated text by replacing underscores with spaces and capitalizing words properly
    /// e.g., "food_catering" -> "Food/Catering", "venue_rental" -> "Venue Rental"
    private func formatAIText(_ text: String) -> String {
        // Replace underscores with spaces
        let formatted = text.replacingOccurrences(of: "_", with: " ")

        // Handle common patterns like "food catering" -> "Food/Catering"
        let slashPatterns = [
            "food catering": "Food/Catering",
            "food and catering": "Food/Catering",
            "audio visual": "Audio/Visual",
            "audio video": "Audio/Video"
        ]

        for (pattern, replacement) in slashPatterns {
            if formatted.lowercased() == pattern {
                return replacement
            }
        }

        // Capitalize each word
        return formatted.capitalized
    }

    private func defaultCoverImageForEventType(_ eventType: EventType) -> String {
        let baseUrl = AppConfig.shared.mediaSourceUrl

        switch eventType {
        case .birthday:
            return "\(baseUrl)/event_covers/birthday/img-1.webp"
        case .wedding:
            return "\(baseUrl)/event_covers/wedding_and_engagement/img-1.webp"
        case .corporate:
            return "\(baseUrl)/event_covers/business/img-1.webp"
        case .conference:
            return "\(baseUrl)/event_covers/business/img-3.webp"
        case .graduation:
            return "\(baseUrl)/event_covers/graduation/img-1.webp"
        case .anniversary:
            return "\(baseUrl)/event_covers/anniversary/img-1.webp"
        case .vacation:
            return "\(baseUrl)/event_covers/vacation/img-1.webp"
        case .babyShower:
            return "\(baseUrl)/event_covers/abstract_covers/background2.jpg"
        case .holiday:
            return "\(baseUrl)/event_covers/abstract_covers/background5.jpg"
        case .custom:
            return "\(baseUrl)/event_covers/collection/img-1.webp"
        }
    }
}
