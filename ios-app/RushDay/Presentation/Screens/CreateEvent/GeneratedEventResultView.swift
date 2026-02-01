import SwiftUI

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Generated Event Result View
struct GeneratedEventResultView: View {
    @ObservedObject var viewModel: CreateEventViewModel
    let onDismiss: () -> Void
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAgenda = false
    @State private var showExpenses = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showCoverSelection = false

    // Header height matches Figma design (449px on 852px screen = ~52.7%)
    private let headerHeight: CGFloat = 449

    /// Dark mode aware background color
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "111827") : Color.rdBackground
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var imagesButton: some View {
        let button = Button("", systemImage: "photo.on.rectangle") {
            showCoverSelection = true
        }
        if #available(iOS 26.0, *) {
            button.glassEffect(.regular)
        } else {
            button
        }
    }

    private var closeButton: some View {
        RDCloseButton { onDismiss() }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) { // Hide scroll indicator
                VStack(spacing: 0) {
                    // Stretchy Cover Header - scales uniformly from center
                    GeometryReader { geometry in
                        let minY = geometry.frame(in: .named("scroll")).minY
                        // Calculate uniform scale factor for stretchy effect
                        let scale = minY > 0 ? 1 + (minY / headerHeight) : 1
                        let offsetY = minY > 0 ? -minY / 2 : 0

                        GeneratedEventCoverHeader(
                            viewModel: viewModel,
                            height: headerHeight
                        )
                        .scaleEffect(scale, anchor: .center) // Scale uniformly from center
                        .offset(y: offsetY)
                        .preference(key: ScrollOffsetPreferenceKey.self, value: minY)
                    }
                    .frame(height: headerHeight)

                    // Tasks Section
                    GeneratedTasksSectionView(viewModel: viewModel)

                    // Agenda Section - always show with Generate button
                    GeneratedAgendaSectionView(
                        viewModel: viewModel,
                        timeFormatter: timeFormatter,
                        isGenerating: viewModel.isGeneratingAgenda
                    )

                    // Expenses Section - always show with Generate/Recalculate button
                    GeneratedExpensesSectionView(
                        viewModel: viewModel,
                        isGenerating: viewModel.isGeneratingExpenses
                    )

                    // Bottom padding for button
                    Color.clear.frame(height: 120)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .scrollBounceHaptic()
            .ignoresSafeArea(edges: .top)

            // Create Event Button
            CreateEventBottomButton(
                isLoading: viewModel.isLoading,
                action: createEvent
            )
        }
        .background(backgroundColor)
        .navigationBarBackButtonHidden(true)
        .if({
            if #available(iOS 26.0, *) { return true }
            return false
        }()) { view in
            view
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem {
                        imagesButton
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed)
                    }
                    ToolbarItem {
                        closeButton
                    }
                }
        }
        .if({
            if #available(iOS 26.0, *) { return false }
            return true
        }()) { view in
            view
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top) {
                    HStack {
                        Spacer()

                        // Right buttons - 32px circles with backdrop blur
                        HStack(spacing: 8) {
                            Button(action: { showCoverSelection = true }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.12))
                                            .background(
                                                BlurView(style: .systemUltraThinMaterialDark)
                                                    .clipShape(Circle())
                                            )
                                    )
                            }

                            Button(action: { onDismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.12))
                                            .background(
                                                BlurView(style: .systemUltraThinMaterialDark)
                                                    .clipShape(Circle())
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
        }
        .sheet(isPresented: $showCoverSelection) {
            CoverSelectionSheet(
                selectedCoverUrl: $viewModel.selectedCoverUrl
            )
        }
    }

    private func createEvent() {
        // Create optimistic event immediately so it shows on home page
        let optimisticId = UUID().uuidString
        let optimisticEvent = Event(
            id: optimisticId,
            name: viewModel.eventName,
            startDate: viewModel.startDate,
            createAt: Date(),
            eventTypeId: viewModel.selectedEventType?.rawValue ?? EventType.custom.rawValue,
            ownerId: appState.currentUser?.id ?? "",
            ownerName: appState.currentUser?.name,
            isCreating: true,
            venue: viewModel.venueName.isEmpty ? nil : viewModel.venueName,
            coverImage: viewModel.selectedCoverUrl
        )

        // Add to AppState immediately (optimistic UI)
        appState.addEvent(optimisticEvent)

        // Dismiss immediately
        onDismiss()

        // Capture for background task
        let appState = self.appState

        // Create event in background with retry
        Task.detached {
            let result = await withRetryResult(policy: .aggressive) {
                let success = await viewModel.createEventWithGeneratedContent()
                if !success {
                    throw NSError(domain: "CreateEvent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create event"])
                }
            }

            // Handle result
            await MainActor.run {
                switch result {
                case .success:
                    // Silently replace optimistic event with real data (no loading)
                    appState.removeEvent(id: optimisticId)
                    // Post notification to trigger silent refresh
                    NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                case .failure(let error, _):
                    // Remove optimistic event and show error
                    appState.removeEvent(id: optimisticId)
                    // Post notification with error to show alert
                    NotificationCenter.default.post(
                        name: NSNotification.Name("EventCreationFailed"),
                        object: nil,
                        userInfo: ["error": error.localizedDescription]
                    )
                case .cancelled:
                    appState.removeEvent(id: optimisticId)
                }
            }
        }
    }
}

// MARK: - Cover Header
struct GeneratedEventCoverHeader: View {
    @ObservedObject var viewModel: CreateEventViewModel
    var height: CGFloat

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US") // Force English
        formatter.dateFormat = "EEEE, MMMM d HH:mm a" // Figma: "Friday, August 17 13:00 PM"
        return formatter
    }()

    /// Returns the default cover image URL based on selected event type
    private var defaultCoverUrl: String {
        let baseUrl = AppConfig.shared.mediaSourceUrl

        guard let eventType = viewModel.selectedEventType else {
            return "\(baseUrl)/event_covers/abstract_covers/background1.jpg"
        }

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

    var body: some View {
        let coverUrl = viewModel.selectedCoverUrl ?? defaultCoverUrl

        ZStack(alignment: .bottom) {
            // Cover Image Background - use selected cover or default based on event type
            CachedAsyncImage(url: URL(string: coverUrl)) { loadedImage in
                loadedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
            } placeholder: {
                // Fallback gradient while loading
                LinearGradient(
                    colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
            }
            .id(coverUrl) // Force refresh when URL changes

            // Blurred image at bottom - true backdrop blur effect with gradient fade
            CachedAsyncImage(url: URL(string: coverUrl)) { loadedImage in
                loadedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .blur(radius: 15)
                    .clipped()
            } placeholder: {
                Color.clear
            }
            .frame(height: height)
            .mask(
                // Gradient mask for seamless blend - starts where title begins
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.72),
                        .init(color: .black, location: 0.82),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Gradient overlay for text readability
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0), location: 0),
                    .init(color: Color.black.opacity(0.2), location: 0.6),
                    .init(color: Color.black.opacity(0.5), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)

            // Event Info at Bottom
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.eventName)
                    .font(.system(size: 28, weight: .semibold, design: .rounded)) // Figma: SF Pro Rounded Semibold
                    .tracking(0.38) // Figma: tracking 0.38px
                    .foregroundColor(.white)

                // Date - Figma: 17px medium, gray-6 color
                HStack(spacing: 8) {
                    Image("icon_calendar")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(hex: "F2F2F7")) // Figma: gray-6

                    Text(dateFormatter.string(from: viewModel.startDate))
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.44)
                        .foregroundColor(Color(hex: "F2F2F7")) // Figma: gray-6
                }

                // Location - Figma: 17px medium, gray-6 color
                if !viewModel.venueName.isEmpty {
                    HStack(spacing: 8) {
                        Image("icon_map_marker")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "F2F2F7")) // Figma: gray-6

                        Text(viewModel.venueName)
                            .font(.system(size: 17, weight: .medium))
                            .tracking(-0.44)
                            .foregroundColor(Color(hex: "F2F2F7")) // Figma: gray-6
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .frame(height: height)
    }
}

// MARK: - Tasks Section
struct GeneratedTasksSectionView: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    /// Check if all tasks are currently selected
    private var allTasksSelected: Bool {
        guard let tasks = viewModel.generatedResponse?.taskList, !tasks.isEmpty else {
            return false
        }
        return viewModel.selectedTasks.count == tasks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header - Figma: "To-Do List" 20px medium, "Select all/Deselect all" 17px purple
            HStack {
                Text("To-Do List")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: toggleSelectAll) {
                    Text(allTasksSelected ? "Deselect all" : "Select all")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(hex: "8251EB"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Tasks List - Figma: White card with 16px corner radius
            if let tasks = viewModel.generatedResponse?.taskList {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.title) { index, task in
                        GeneratedTaskRow(
                            title: task.title,
                            isSelected: viewModel.selectedTasks.contains(task.title),
                            isFirst: index == 0,
                            isLast: index == tasks.count - 1,
                            colorScheme: colorScheme,
                            onToggle: {
                                toggleTask(task.title)
                            }
                        )

                        if index < tasks.count - 1 {
                            Divider()
                                .background(theme.divider)
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(theme.cardBackgroundSolid)
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }
        }
    }

    private func toggleSelectAll() {
        if allTasksSelected {
            // Deselect all
            viewModel.selectedTasks.removeAll()
        } else {
            // Select all
            if let tasks = viewModel.generatedResponse?.taskList {
                viewModel.selectedTasks = Set(tasks.map { $0.title })
            }
        }
    }

    private func toggleTask(_ title: String) {
        if viewModel.selectedTasks.contains(title) {
            viewModel.selectedTasks.remove(title)
        } else {
            viewModel.selectedTasks.insert(title)
        }
    }
}

struct GeneratedTaskRow: View {
    let title: String
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    let colorScheme: ColorScheme
    let onToggle: () -> Void

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Figma: Task text 17px regular
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Figma: Checkbox 24px, gray unselected, purple selected
                Circle()
                    .fill(isSelected ? Color(hex: "8251EB") : (colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA"))
                            }
                        }
                    )
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agenda Section
struct GeneratedAgendaSectionView: View {
    @ObservedObject var viewModel: CreateEventViewModel
    let timeFormatter: DateFormatter
    var isGenerating: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    private var hasAgenda: Bool {
        guard let agenda = viewModel.generatedResponse?.agenda else { return false }
        return !agenda.isEmpty
    }

    private func generateMoreAgenda() {
        Task {
            await viewModel.generateAgenda()
        }
    }

    private var groupedAgenda: [(day: Int, date: Date, items: [GeneratedAgendaItem])] {
        guard let agendaItems = viewModel.generatedResponse?.agenda, !agendaItems.isEmpty else {
            return []
        }

        let calendar = Calendar.current
        let baseDate = agendaItems.first?.startTime ?? Date()
        let baseDayStart = calendar.startOfDay(for: baseDate)

        var groups: [Int: (date: Date, items: [GeneratedAgendaItem])] = [:]

        for item in agendaItems {
            let itemDayStart = calendar.startOfDay(for: item.startTime)
            let daysDiff = calendar.dateComponents([.day], from: baseDayStart, to: itemDayStart).day ?? 0
            let dayIndex = max(0, daysDiff) + 1 // Day 1, Day 2, etc.

            if groups[dayIndex] == nil {
                groups[dayIndex] = (date: item.startTime, items: [])
            }
            groups[dayIndex]?.items.append(item)
        }

        return groups.keys.sorted().map { day in
            (day: day, date: groups[day]!.date, items: groups[day]!.items)
        }
    }

    private let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header - Figma: 20px medium
            Text("Agenda")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Agenda Items grouped by day
            let groups = groupedAgenda
            if !groups.isEmpty {
                if groups.count == 1 {
                    // Single day - no day header needed
                    VStack(spacing: 8) {
                        ForEach(groups[0].items) { item in
                            GeneratedAgendaRow(
                                activity: item.activity,
                                startTime: timeFormatter.string(from: item.startTime),
                                endTime: timeFormatter.string(from: item.endTime),
                                colorScheme: colorScheme,
                                onDelete: {
                                    removeAgendaItem(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Multi-day - show day headers
                    VStack(spacing: 16) {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Day header
                                Text("Day \(group.day), \(dayDateFormatter.string(from: group.date))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)

                                // Items for this day
                                ForEach(group.items) { item in
                                    GeneratedAgendaRow(
                                        activity: item.activity,
                                        startTime: timeFormatter.string(from: item.startTime),
                                        endTime: timeFormatter.string(from: item.endTime),
                                        colorScheme: colorScheme,
                                        onDelete: {
                                            removeAgendaItem(item)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Always show Generate Agenda button - adds more items without duplicates
            Button(action: generateMoreAgenda) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "8251EB")))
                            .scaleEffect(0.8)
                    } else {
                        Image("icon_ai_generate")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "8251EB"))

                        // Show "Add More" if agenda exists, "Generate Agenda" if not
                        Text(hasAgenda ? "Add More" : "Generate Agenda")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "8251EB"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.cardBackgroundSolid)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "8251EB"), lineWidth: 1)
                )
            }
            .disabled(isGenerating)
            .padding(.horizontal, 16)
            .padding(.top, groups.isEmpty ? 0 : 16)
        }
    }

    private func removeAgendaItem(_ item: GeneratedAgendaItem) {
        guard var agenda = viewModel.generatedResponse?.agenda else { return }
        agenda.removeAll { $0.id == item.id }
        // Update the response with the new agenda
        if let response = viewModel.generatedResponse {
            viewModel.generatedResponse = EventAiResponse(
                agenda: agenda,
                taskList: response.taskList,
                budgetBreakdown: response.budgetBreakdown,
                totalBudget: response.totalBudget
            )
        }
    }
}

struct GeneratedAgendaRow: View {
    let activity: String
    let startTime: String
    let endTime: String
    var colorScheme: ColorScheme = .light
    var onDelete: (() -> Void)?

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        // Figma: Card and bin icon are siblings, bin is outside the card
        HStack(spacing: 16) {
            // Card containing time and activity
            VStack(alignment: .leading, spacing: 2) {
                Text("\(startTime) - \(endTime)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "A17BF4"))

                Text(activity)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .tracking(-0.44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.cardBackgroundSolid)
            .cornerRadius(12)

            // Bin icon outside the card
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image("icon_bin")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "A17BF4"))
                }
            }
        }
    }
}

// MARK: - Expenses Section
struct GeneratedExpensesSectionView: View {
    @ObservedObject var viewModel: CreateEventViewModel
    var isGenerating: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    private var hasExpenses: Bool {
        guard let budget = viewModel.generatedResponse?.budgetBreakdown else { return false }
        return !budget.isEmpty
    }

    private func generateOrRecalculateExpenses() {
        Task {
            // Pass recalculate: true if expenses already exist
            await viewModel.generateExpenses(recalculate: hasExpenses)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header - Figma: 20px medium
            Text("Expenses")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Expenses List (if we have any)
            if let budgetItems = viewModel.generatedResponse?.budgetBreakdown, !budgetItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(budgetItems.enumerated()), id: \.element.id) { index, item in
                        GeneratedExpenseRow(
                            category: item.category,
                            amount: item.estimatedCost,
                            currencySymbol: viewModel.selectedCurrency.symbol,
                            colorScheme: colorScheme,
                            isTotal: false
                        )

                        if index < budgetItems.count - 1 {
                            Divider()
                                .background(theme.divider)
                                .padding(.leading, 16)
                        }
                    }

                    // Divider before total
                    Divider()
                        .background(theme.divider)
                        .padding(.leading, 16)

                    // Total Row
                    if let total = viewModel.generatedResponse?.totalBudget {
                        GeneratedExpenseRow(
                            category: L10n.total,
                            amount: Double(total),
                            currencySymbol: viewModel.selectedCurrency.symbol,
                            colorScheme: colorScheme,
                            isTotal: true
                        )
                    }
                }
                .background(theme.cardBackgroundSolid)
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }

            // Always show Generate/Recalculate button
            Button(action: generateOrRecalculateExpenses) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "8251EB")))
                            .scaleEffect(0.8)
                    } else {
                        Image("icon_ai_generate")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "8251EB"))

                        // Show "Recalculate" if expenses exist, "Calculate Expenses" if not
                        Text(hasExpenses ? "Recalculate" : "Calculate Expenses")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "8251EB"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.cardBackgroundSolid)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "8251EB"), lineWidth: 1)
                )
            }
            .disabled(isGenerating)
            .padding(.horizontal, 16)
            .padding(.top, hasExpenses ? 16 : 0)
        }
    }
}

struct GeneratedExpenseRow: View {
    let category: String
    let amount: Double
    let currencySymbol: String
    var colorScheme: ColorScheme = .light
    let isTotal: Bool

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack {
            Text(category)
                .font(.system(size: 15, weight: isTotal ? .semibold : .medium))
                .foregroundColor(theme.textPrimary)

            Spacer()

            Text("\(formatAmount(amount)) \(currencySymbol)")
                .font(.system(size: 15, weight: isTotal ? .semibold : .regular))
                .foregroundColor(isTotal ? .rdWarning : .rdPrimary)
        }
        .padding(16)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

// MARK: - Create Event Bottom Button
struct CreateEventBottomButton: View {
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            RDGradientButton(
                L10n.createEvent,
                isLoading: isLoading,
                height: 52,
                action: action
            )
            .padding(.horizontal, 16)

            // Safe Area / Home Indicator
            Color.clear.frame(height: 34)
        }
        .background(colorScheme == .dark ? Color(hex: "111827") : Color.rdBackground)
    }
}

#Preview {
    let viewModel = CreateEventViewModel()
    viewModel.eventName = "John's Birthday Party"
    viewModel.generatedResponse = EventAiResponse(
        agenda: [
            GeneratedAgendaItem(startTime: Date(), endTime: Date().addingTimeInterval(3600), activity: "Guest Arrival"),
            GeneratedAgendaItem(startTime: Date().addingTimeInterval(3600), endTime: Date().addingTimeInterval(7200), activity: "Dinner"),
            GeneratedAgendaItem(startTime: Date().addingTimeInterval(7200), endTime: Date().addingTimeInterval(9000), activity: "Cake Cutting"),
        ],
        taskList: [
            GeneratedTask(title: "Gather inputs about birthday person's preference, create a personal theme."),
            GeneratedTask(title: "Purchase or craft theme-based decorations, prioritize low-cost or DIY options."),
            GeneratedTask(title: "Coordinate the photographer, discuss specific shots or moments to capture."),
            GeneratedTask(title: "Design and send digital invitations, track RSVPs."),
            GeneratedTask(title: "Check for dietary restrictions, accessibility requirements."),
        ],
        budgetBreakdown: [
            GeneratedBudgetItem(category: "Venue", estimatedCost: 0),
            GeneratedBudgetItem(category: "Food/Catering", estimatedCost: 0),
            GeneratedBudgetItem(category: "Decor", estimatedCost: 0),
            GeneratedBudgetItem(category: "Entertainment", estimatedCost: 0),
            GeneratedBudgetItem(category: "Invitations", estimatedCost: 0),
            GeneratedBudgetItem(category: "Miscellaneous", estimatedCost: 0),
        ],
        totalBudget: 0
    )
    viewModel.selectedTasks = Set(viewModel.generatedResponse!.taskList.map { $0.title })

    return GeneratedEventResultView(viewModel: viewModel, onDismiss: {})
}
