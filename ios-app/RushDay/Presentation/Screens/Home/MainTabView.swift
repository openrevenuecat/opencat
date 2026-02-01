import SwiftUI

// MARK: - Event Filter Type
@MainActor
enum EventFilterType: String, CaseIterable {
    case upcoming
    case past
    case draft

    var displayText: String {
        switch self {
        case .upcoming: return L10n.upcoming
        case .past: return L10n.past
        case .draft: return L10n.drafts
        }
    }
}

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var currentFilter: EventFilterType = .upcoming
    @Published var isLoading = true  // Start true to show shimmer on initial load
    @Published var user: User?
    @Published var errorMessage: String?

    // Reference to AppState for single source of truth
    private weak var appState: AppState?
    private let grpcService: GRPCClientService
    private let authService: AuthServiceProtocol
    private let taskRepository: TaskRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol
    private let guestRepository: GuestRepositoryProtocol

    init(
        appState: AppState? = nil,
        grpcService: GRPCClientService = .shared,
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        taskRepository: TaskRepositoryProtocol = DIContainer.shared.taskRepository,
        expenseRepository: ExpenseRepositoryProtocol = DIContainer.shared.expenseRepository,
        guestRepository: GuestRepositoryProtocol = DIContainer.shared.guestRepository
    ) {
        self.appState = appState
        self.grpcService = grpcService
        self.authService = authService
        self.taskRepository = taskRepository
        self.expenseRepository = expenseRepository
        self.guestRepository = guestRepository
        // Start with Firebase Auth user, will be replaced with full user from gRPC
        self.user = authService.currentUser
    }

    /// Set the appState reference (called from view)
    func setAppState(_ appState: AppState) {
        self.appState = appState
        // If we have cached events, hide shimmer immediately
        if !appState.events.isEmpty {
            self.isLoading = false
        }
    }

    func loadEvents(showLoading: Bool = true) async {
        errorMessage = nil

        // Ensure auth token is set before making gRPC request
        await ensureAuthToken()

        // Load user from gRPC (has full profile including avatar)
        await loadUser()

        // Load events into AppState (single source of truth)
        await appState?.loadEvents()

        // Always hide shimmer after loading completes
        isLoading = false

        // Check Rate Us conditions after view has settled
        await checkRateUsConditions()
    }

    func changeFilter(_ filter: EventFilterType) {
        currentFilter = filter
    }

    private func ensureAuthToken() async {
        guard let firebaseUser = authService.currentFirebaseUser else {
            return
        }

        do {
            // Force refresh to ensure we have a valid, fresh token
            let token = try await firebaseUser.getIDToken(forcingRefresh: true)
            grpcService.setAuthToken(token)
        } catch {
            // Token refresh failed
        }
    }

    private func loadUser() async {
        do {
            let grpcUser = try await grpcService.getCurrentUser()
            let domainUser = User(from: grpcUser)
            self.user = domainUser
        } catch {
            // Keep the Firebase Auth user as fallback
        }
    }

    private func checkRateUsConditions() async {
        guard let events = appState?.events, !events.isEmpty else { return }
        guard let currentUserId = authService.currentUser?.id else { return }

        await RateUsService.shared.checkAndShowIfNeeded(
            events: events,
            currentUserId: currentUserId,
            taskRepository: taskRepository,
            guestRepository: guestRepository,
            expenseRepository: expenseRepository
        )
    }
}

// MARK: - Home Screen
struct HomeScreen: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showCreateEvent = false
    @State private var showProfile = false
    @State private var navigationPath = NavigationPath()

    @State private var showRateUs = false
    @State private var showContactUs = false
    @State private var showEventCreationError = false
    @State private var eventCreationErrorMessage: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HomeNavigationBar(
                    viewModel: viewModel,
                    showCreateEvent: $showCreateEvent,
                    showProfile: $showProfile
                )

                // Content
                if viewModel.isLoading {
                    HomeLoadingView()
                } else {
                    HomeContentView(
                        viewModel: viewModel,
                        showCreateEvent: $showCreateEvent
                    )
                }
            }
            .background(Color.rdBackground)
            .navigationBarHidden(true)
            .navigationDestination(for: Event.self) { event in
                EventDetailsView(event: event, appState: appState)
            }
            .navigationDestination(for: EventDetailsDestination.self) { destination in
                switch destination {
                case .guests(let eventId, let initialTab):
                    GuestsListView(eventId: eventId, appState: appState, initialTab: initialTab)
                case .tasks(let eventId):
                    TasksListView(eventId: eventId)
                case .agenda(let eventId, let eventDate):
                    AgendaListView(eventId: eventId, eventDate: eventDate)
                case .expenses(let eventId):
                    ExpensesListView(eventId: eventId)
                case .aiChat(let event):
                    AIEventChatView(event: event)
                case .contactUs:
                    ContactUsView()
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .onChange(of: showProfile) { _, isShowingProfile in
                // Reset navigation path when returning from Profile to fix SwiftUI NavigationStack bug
                if !isShowingProfile && !navigationPath.isEmpty {
                    navigationPath = NavigationPath()
                }
            }
        }
        .task {
            // Set appState reference for single source of truth
            viewModel.setAppState(appState)
            // Only show loading on first load (no events yet)
            // This prevents loading spinner when returning from event creation (optimistic UI)
            let isFirstLoad = appState.events.isEmpty
            await viewModel.loadEvents(showLoading: isFirstLoad)
        }
        .onChange(of: appState.isMigrating) { _, isMigrating in
            // Reload events when migration completes (silent refresh)
            if !isMigrating {
                Task {
                    await viewModel.loadEvents(showLoading: false)
                }
            }
        }
        .onChange(of: appState.shouldReloadApp) { _, shouldReload in
            // Reload app when cache is cleared (for testing shimmer)
            if shouldReload {
                appState.shouldReloadApp = false
                // Reset HomeViewModel loading state to show shimmer
                viewModel.isLoading = true
                Task {
                    await viewModel.loadEvents(showLoading: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventUpdated"))) { _ in
            // Reload events when an event is updated (e.g., cover image changed)
            Task {
                await viewModel.loadEvents(showLoading: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
            // Silently reload events when a new event is created (optimistic UI)
            Task {
                await viewModel.loadEvents(showLoading: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreationFailed"))) { notification in
            // Show error alert when event creation fails
            if let error = notification.userInfo?["error"] as? String {
                eventCreationErrorMessage = error
            } else {
                eventCreationErrorMessage = "Failed to create event. Please try again."
            }
            showEventCreationError = true
        }
        .alert("Event Creation Failed", isPresented: $showEventCreationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(eventCreationErrorMessage ?? "Failed to create event. Please try again.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { notification in
            // Update user when profile is changed
            if let updatedUser = notification.object as? User {
                viewModel.user = updatedUser
            }
        }
        .fullScreenCover(isPresented: $showCreateEvent, onDismiss: {
            // Silently reload events in background without showing loading state
            Task {
                await viewModel.loadEvents(showLoading: false)
            }
        }) {
            AIEventPlannerView(
                onComplete: { pendingData in
                    appState.completeAIPlanner(with: pendingData)
                    showCreateEvent = false
                },
                onDismiss: {
                    appState.cancelAIPlannerFlow()
                    showCreateEvent = false
                },
                showCloseButton: true,
                skipWelcome: true
            )
            .environmentObject(appState)
        }
        .onChange(of: appState.navigateToEvent) { (_: Event?, newEvent: Event?) in
            if let event = newEvent {
                // Push the event onto navigation stack
                navigationPath.append(event)
                // Clear the trigger
                appState.navigateToEvent = nil
            }
        }
        .onReceive(RateUsService.shared.$showRateUs) { value in
            if value {
                showRateUs = true
                RateUsService.shared.showRateUs = false
            }
        }
        .alert("Your Opinion Matters", isPresented: $showRateUs) {
            Button("Love it!") {
                RateUsService.shared.handleLoveIt()
            }
            Button("Not really") {
                RateUsService.shared.handleNotReally()
                showContactUs = true
            }
            Button("Ask me later", role: .cancel) {
                RateUsService.shared.handleAskLater()
            }
        } message: {
            Text("Share your experience with a quick rating")
        }
        .sheet(isPresented: $showContactUs) {
            ContactUsView()
        }
    }
}

// MARK: - Home Navigation Bar
struct HomeNavigationBar: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Binding var showCreateEvent: Bool
    @Binding var showProfile: Bool

    var body: some View {
        HStack {
            // Left: Filter Button
            EventFilterButton(viewModel: viewModel)

            Spacer()

            // Right: Actions
            HStack(spacing: 16) {
                CreateEventButton(showCreateEvent: $showCreateEvent)
                ProfileAvatarButton(
                    user: appState.currentUser, // Use centralized user from AppState
                    showProfile: $showProfile
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.rdBackground)
    }
}

// MARK: - Event Filter Button
struct EventFilterButton: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        // Always show the filter menu - no loading state needed
        Menu {
            ForEach(EventFilterType.allCases, id: \.self) { filter in
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewModel.changeFilter(filter)
                    }
                } label: {
                    if viewModel.currentFilter == filter {
                        Label(filter.displayText, systemImage: "checkmark")
                    } else {
                        Text(filter.displayText)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(viewModel.currentFilter.displayText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(.rdTextPrimary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.rdPrimary)
                    .frame(width: 20, height: 20)
            }
        }
        .id(viewModel.currentFilter) // Force stable identity
    }
}

// MARK: - Create Event Button
struct CreateEventButton: View {
    @Binding var showCreateEvent: Bool

    var body: some View {
        Button {
            showCreateEvent = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.rdPrimary, in: Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style (for circular buttons with press animation)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Profile Avatar Button
struct ProfileAvatarButton: View {
    let user: User?
    @Binding var showProfile: Bool

    var body: some View {
        Button {
            showProfile = true
        } label: {
            if let photoURL = user?.photoURL, !photoURL.isEmpty {
                CachedAsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProfilePlaceholder(user: user)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .id(photoURL) // Force view recreation when URL changes
            } else {
                ProfilePlaceholder(user: user)
                    .frame(width: 40, height: 40)
            }
        }
    }
}

struct ProfilePlaceholder: View {
    let user: User?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.rdPrimary)

            if let initials = user?.initials {
                Text(initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Home Content View
struct HomeContentView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Binding var showCreateEvent: Bool

    /// Filtered events based on current filter - reads directly from AppState
    private var filteredEvents: [Event] {
        switch viewModel.currentFilter {
        case .upcoming:
            return appState.events.filter { !$0.isMovedToDraft && ($0.isUpcoming || Calendar.current.isDateInToday($0.startDate)) }
        case .past:
            return appState.events.filter { !$0.isMovedToDraft && $0.isPast && !Calendar.current.isDateInToday($0.startDate) }
        case .draft:
            return appState.draftEvents
        }
    }

    var body: some View {
        ZStack {
            if filteredEvents.isEmpty {
                HomeEmptyState(
                    filter: viewModel.currentFilter,
                    showCreateEvent: $showCreateEvent
                )
                .transition(.opacity)
            } else {
                EventListView(
                    events: filteredEvents,
                    isPastFilter: viewModel.currentFilter == .past
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentFilter)
    }
}

// MARK: - Event List View
struct EventListView: View {
    let events: [Event]
    var isPastFilter: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        HomeEventCard(event: event, showOpacity: isPastFilter)
                            .id("\(event.id)-\(event.coverImage ?? "default")") // Force refresh when cover image changes
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 64)
        }
        .scrollBounceHaptic()
    }
}

// MARK: - Home Event Card (Large Card with Cover Image)
struct HomeEventCard: View {
    let event: Event
    var showOpacity: Bool = false

    @State private var coverImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            let cardHeight = geometry.size.height
            ZStack(alignment: .bottom) {
                // Cover Image - fills entire card (uses effectiveCoverImage which includes type-based default)
                CoverImageView(
                    imageURL: event.effectiveCoverImage,
                    showOpacity: showOpacity,
                    onImageLoaded: { coverImage = $0 }
                )
                .frame(width: geometry.size.width, height: cardHeight)
                .clipped()

                // Event Information Overlay with blur behind it
                EventInfoOverlay(event: event)
                    .background(
                        Group {
                            if let coverImage {
                                GeometryReader { overlayGeo in
                                    Image(uiImage: coverImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: overlayGeo.size.width + 80, height: cardHeight + 80)
                                        .blur(radius: 10)
                                        .frame(width: overlayGeo.size.width, height: overlayGeo.size.height)
                                        .clipped()
                                }
                            }
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(height: UIScreen.main.bounds.height * 0.6)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Cover Image View
struct CoverImageView: View {
    let imageURL: String  // Now always receives a valid URL (effectiveCoverImage provides defaults)
    var showOpacity: Bool = false
    var onImageLoaded: ((UIImage) -> Void)?

    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = loadedImage {
                // Successfully loaded image from cache
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                // Loading state
                placeholderImage
                    .shimmer()
            } else {
                // Error/fallback state
                placeholderImage
            }
        }
        .clipped()
        .overlay(
            showOpacity ? Color.white.opacity(0.2) : Color.clear
        )
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private var placeholderImage: some View {
        LinearGradient(
            colors: [Color.rdPrimary.opacity(0.8), Color.rdAccent.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
        )
    }

    private func loadImage() async {
        isLoading = true

        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: imageURL) {
            loadedImage = cachedImage
            onImageLoaded?(cachedImage)
            isLoading = false
            return
        }

        // Download if not in cache
        guard let url = URL(string: imageURL) else {
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let downloadedImage = UIImage(data: data) else {
                isLoading = false
                return
            }

            // Cache and set
            ImageCache.shared.set(downloadedImage, forKey: imageURL)
            loadedImage = downloadedImage
            onImageLoaded?(downloadedImage)
        } catch {
            // Silent fail - placeholder will show
        }

        isLoading = false
    }
}

// MARK: - Event Info Overlay
struct EventInfoOverlay: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event Name - SF Pro Rounded Semibold 28pt with line height 34pt
            Text(event.name)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .tracking(0.38)
                .foregroundColor(.white)
                .lineSpacing(6) // 34pt line height - 28pt font size = 6pt line spacing
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 8) {
                // Date
                EventInfoRow(
                    icon: "calendar",
                    text: formatDateRange(event.startDate, event.endDate)
                )

                // Venue
                if let venue = event.venue, !venue.isEmpty {
                    EventInfoRow(
                        icon: "mappin.and.ellipse",
                        text: venue
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }

    private func formatDateRange(_ start: Date, _ end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "MMM d, yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "h:mm a"

        var result = dateFormatter.string(from: start)

        if let end = end {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                result += " • \(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
            } else {
                result += " - \(dateFormatter.string(from: end))"
            }
        } else {
            result += " • \(timeFormatter.string(from: start))"
        }

        return result
    }
}

// MARK: - Event Info Row
struct EventInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .foregroundColor(Color(red: 242/255, green: 242/255, blue: 247/255)) // Grays/Gray 6 #F2F2F7
                .lineLimit(1)
        }
    }
}

// MARK: - Blurred Background (Glassmorphism Effect)
struct BlurredBackground: View {
    var body: some View {
        // Backdrop blur with gradient mask for smooth fade
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        colors: [
                            .black.opacity(0.3),
                            .black.opacity(0.6),
                            .black,
                            .black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            Color.black.opacity(0.2)
        }
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var blurRadius: CGFloat = 10

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: blurStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)

        // Apply custom blur radius by scaling the effect
        // Note: This is a workaround as UIKit doesn't directly support custom blur radius
        // The blur will be enhanced by the intensity parameter
        blurView.layer.masksToBounds = true

        return blurView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Home Empty State
struct HomeEmptyState: View {
    let filter: EventFilterType
    @Binding var showCreateEvent: Bool

    var title: String {
        switch filter {
        case .upcoming: return L10n.emptyUpcomingTitle
        case .past: return L10n.emptyPastTitle
        case .draft: return L10n.emptyDraftTitle
        }
    }

    var description: String {
        switch filter {
        case .upcoming: return L10n.emptyUpcomingDesc
        case .past: return L10n.emptyPastDesc
        case .draft: return L10n.emptyDraftDesc
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: UIScreen.main.bounds.height * 0.24)

            // Calendar Placeholder SVG
            Image("calendar_placeholder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 137, height: 168)

            // Title and description on separate lines (matching Figma)
            // SF Pro Regular 15px, line-height 20px, tracking -0.23px
            VStack(spacing: 0) {
                Text(title)
                    .foregroundColor(Color(hex: "83828D"))

                Text(description)
                    .foregroundColor(Color(hex: "9E9EAA"))
            }
            .font(.system(size: 15, weight: .regular))
            .tracking(-0.23)
            .lineSpacing(5) // 20px line height - 15px font = 5px
            .multilineTextAlignment(.center)
            .frame(width: 361)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Home Loading View
struct HomeLoadingView: View {
    var body: some View {
        HomeEventsShimmerView()
            .scrollBounceHaptic()
    }
}

#Preview {
    HomeScreen()
        .environmentObject(AppState())
}
