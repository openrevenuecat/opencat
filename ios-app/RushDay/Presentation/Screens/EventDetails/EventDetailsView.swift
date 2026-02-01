import SwiftUI
import UIKit
import EventKit
import Combine

// MARK: - Blur View Helper
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Event Details View
struct EventDetailsView: View {
    @StateObject private var viewModel: EventDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var paywallSource: String = ""
    @State private var paywallAction: (() -> Void)?
    @State private var showCoverImagePicker = false
    @State private var selectedCoverUrl: String?
    @State private var showAddHostShare = false
    @State private var generatedInviteLink: String?
    @State private var isGeneratingLink = false
    @State private var selectedCoHost: SharedUser?
    @State private var showCoHostDetails = false
    @State private var showContactUs = false

    /// AppState passed via init - avoids @EnvironmentObject to prevent render loops
    /// when AppState's other @Published properties change
    private let storedAppState: AppState
    private var appState: AppState { storedAppState }

    init(event: Event, appState: AppState) {
        self.storedAppState = appState
        _viewModel = StateObject(wrappedValue: EventDetailsViewModel(event: event, appState: appState))
    }

    // MARK: - Toolbar Buttons

    private var backButton: some View {
        Button("", systemImage: "chevron.left") { dismiss() }
    }

    @ViewBuilder
    private var imagesButton: some View {
        let button = Button("", systemImage: "photo.on.rectangle") {
            showCoverImagePicker = true
        }
        if #available(iOS 26.0, *) {
            button.glassEffect(.regular.interactive())
        } else {
            button
        }
    }

    @ViewBuilder
    private var menuButton: some View {
        let menu = Menu {
            Button {
                viewModel.editEvent()
            } label: {
                Label {
                    Text(L10n.editEvent)
                } icon: {
                    Image("icon_pencil_edit")
                }
            }

            Divider()

            Button {
                viewModel.addToCalendar()
            } label: {
                Label {
                    Text(L10n.addToCalendar)
                } icon: {
                    Image("icon_calendar_add")
                }
            }

            // Only show "Move to Drafts" if event is not already a draft
            if !viewModel.event.isMovedToDraft {
                Button {
                    viewModel.moveToDrafts()
                } label: {
                    Label {
                        Text(L10n.moveToDrafts)
                    } icon: {
                        Image("icon_file")
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteEvent()
            } label: {
                Label {
                    Text(L10n.deleteEvent)
                } icon: {
                    Image("icon_bin")
                }
            }
        } label: {
            Label("", systemImage: "ellipsis")
        }

        if #available(iOS 26.0, *) {
            menu.glassEffect(.regular.interactive())
        } else {
            menu
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section with Cover Image (with stretchy header effect)
                    GeometryReader { scrollGeometry in
                        EventHeroSection(
                            event: viewModel.event,
                            confirmedGuests: viewModel.confirmedGuests,
                            pendingGuests: viewModel.pendingGuests,
                            declinedGuests: viewModel.declinedGuests,
                            scrollOffset: scrollGeometry.frame(in: .global).minY
                        )
                    }
                    .frame(height: 574)

                    // Content Section with background
                    VStack(spacing: 16) {
                        // Event Details Card
                        EventDetailsCard(
                            event: viewModel.event,
                            onAddVenue: { viewModel.editEvent() },
                            onAddNote: { viewModel.editEvent() }
                        )
                        .padding(.horizontal, 16)

                        // Preview Invitation Button
                        PreviewInvitationButton(
                            event: viewModel.event,
                            owner: appState.currentUser,
                            onEventUpdated: { updatedEvent in
                                viewModel.updateEvent(updatedEvent)
                                appState.updateEvent(updatedEvent)
                            }
                        )

                        // Host Section
                        HostedBySection(
                            event: viewModel.event,
                            onAddHost: handleAddHost,
                            onSelectCoHost: { coHost in
                                selectedCoHost = coHost
                                showCoHostDetails = true
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color.rdBackground)
                }
            }
            .scrollBounceHaptic()
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                // Floating AI Chat Button - per Figma node 3103:44273
                NavigationLink(value: EventDetailsDestination.aiChat(event: viewModel.event)) {
                    AIAvatarView(size: .small, isAnimating: true)
                }
                .padding(.trailing, 20) // Per Figma right-[20px]
                .padding(.bottom, 64) // Per Figma bottom-[30px] + home indicator
            }
        }
        .navigationBarBackButtonHidden(true)
        .if({
            if #available(iOS 26.0, *) { return true }
            return false
        }()) { view in
            view
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        backButton
                    }
                    ToolbarItem {
                        imagesButton
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed)
                    }
                    ToolbarItem {
                        menuButton
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
                        // Back button - simple white chevron, no background
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        // Right buttons - 32px circles with backdrop blur
                        HStack(spacing: 8) {
                            Button(action: { showCoverImagePicker = true }) {
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

                            Menu {
                                Button { viewModel.editEvent() } label: {
                                    Label(L10n.editEvent, image: "icon_pencil_edit")
                                }
                                Divider()
                                Button { viewModel.addToCalendar() } label: {
                                    Label(L10n.addToCalendar, image: "icon_calendar_add")
                                }
                                if !viewModel.event.isMovedToDraft {
                                    Button { viewModel.moveToDrafts() } label: {
                                        Label(L10n.moveToDrafts, image: "icon_file")
                                    }
                                }
                                Divider()
                                Button(role: .destructive) { viewModel.deleteEvent() } label: {
                                    Label(L10n.deleteEvent, image: "icon_bin")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
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
        .enableSwipeBackGesture()
        .task {
            await viewModel.refreshEvent()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshEventData"))) { notification in
            // Refresh when a push notification indicates event data changed (e.g., co-host accepted)
            if let eventId = notification.userInfo?["eventId"] as? String,
               eventId == viewModel.event.id {
                Task {
                    await viewModel.refreshEvent()
                }
            } else if notification.userInfo?["eventId"] == nil {
                // No specific eventId means refresh all
                Task {
                    await viewModel.refreshEvent()
                }
            }
        }
        .navigationDestination(isPresented: $showContactUs) {
            ContactUsView()
        }
        .fullScreenCover(isPresented: $viewModel.showEditEvent) {
            EditEventView(
                event: viewModel.event,
                onEventUpdated: { updatedEvent in
                    // Update local view model
                    viewModel.updateEvent(updatedEvent)
                    // Update AppState (single source of truth)
                    appState.updateEvent(updatedEvent)
                },
                onEventDeleted: {
                    // Remove from AppState
                    appState.removeEvent(id: viewModel.event.id)
                    dismiss()
                }
            )
        }
        .alert(L10n.deleteEvent, isPresented: $viewModel.showDeleteConfirmation) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                Task {
                    await viewModel.confirmDeleteEvent()
                    // Remove from AppState (single source of truth)
                    appState.removeEvent(id: viewModel.event.id)
                }
            }
        } message: {
            Text(L10n.deleteEventConfirmation)
        }
        .alert(viewModel.calendarAlertTitle, isPresented: $viewModel.showCalendarAlert) {
            if viewModel.calendarAlertTitle == "Calendar Access Required" {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(viewModel.calendarAlertMessage)
        }
        .alert("Move to Drafts", isPresented: $viewModel.showMoveToDraftsAlert) {
            Button("OK", role: .cancel) {
                // Dismiss after successful move to drafts
                if viewModel.moveToDraftsAlertMessage.contains("has been moved") {
                    appState.moveEventToDrafts(id: viewModel.event.id)
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.moveToDraftsAlertMessage)
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .sheet(isPresented: $showPaywall) {
            FeaturePaywallSheet(source: paywallSource) {
                appState.updateSubscriptionStatus(true)
                paywallAction?()
                paywallAction = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(
                LinearGradient(
                    colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
        }
        .sheet(isPresented: $showCoverImagePicker) {
            CoverSelectionSheet(selectedCoverUrl: $selectedCoverUrl)
                .presentationDetents([.height(340), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddHostShare) {
            if let inviteLink = generatedInviteLink {
                ShareSheet(items: [inviteLink])
            }
        }
        .sheet(isPresented: $showCoHostDetails) {
            if let coHost = selectedCoHost {
                CoHostDetailsView(
                    sharedUser: coHost,
                    event: viewModel.event,
                    onRemove: { sharedUser in
                        viewModel.removeCoHost(sharedUser)
                    },
                    onAccessRoleChanged: { sharedUser, newRole in
                        viewModel.updateCoHostAccessRole(sharedUser, to: newRole)
                    },
                    onDismiss: {
                        showCoHostDetails = false
                        selectedCoHost = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: selectedCoverUrl) { oldValue, newValue in
            if let newValue = newValue, newValue != viewModel.event.coverImage {
                viewModel.updateCoverImage(newValue)
            }
        }
    }

    private func openPaywall(source: String, action: @escaping () -> Void) {
        paywallSource = source
        paywallAction = action
        showPaywall = true
    }

    private func handleAddHost() {
        if appState.isSubscribed {
            generateAndShareInviteLink()
        } else {
            openPaywall(source: "add_host") {
                generateAndShareInviteLink()
            }
        }
    }

    private func generateAndShareInviteLink() {
        guard !isGeneratingLink else { return }

        isGeneratingLink = true

        Task {
            do {
                // Call backend to create a SharedUser slot with unique secret
                // The secret is a one-time use token that expires when accepted
                let updatedEvent = try await GRPCClientService.shared.shareEvent(
                    eventId: viewModel.event.id,
                    name: "Co-Host" // Generic name, will be replaced when user accepts
                )

                // Get the secret from the newly created SharedUser
                // The last shared user in the list is the one we just created
                guard let newSharedUser = updatedEvent.shared.last else {
                    await MainActor.run {
                        isGeneratingLink = false
                    }
                    return
                }

                let secret = newSharedUser.secret

                // Generate AppsFlyer OneLink format with secret
                // Format: https://app.rush-day.io/{appsFlyerAppId}?deep_link_value=/invite?secret={secret}&af_force_deeplink=true
                let config = AppConfig.shared
                let domain = config.oneLinkDomain
                let appId = config.appsFlyerOneLinkId

                let deepLinkValue = "/invite?secret=\(secret)"

                var components = URLComponents()
                components.scheme = "https"
                components.host = domain
                components.path = "/\(appId)"
                components.queryItems = [
                    URLQueryItem(name: "deep_link_value", value: deepLinkValue),
                    URLQueryItem(name: "af_force_deeplink", value: "true")
                ]

                await MainActor.run {
                    // Update local event with the new SharedUser (map from gRPC to domain)
                    let domainEvent = Event(from: updatedEvent)
                    viewModel.updateEvent(domainEvent)
                    appState.updateEvent(domainEvent)

                    if let inviteUrl = components.url?.absoluteString {
                        generatedInviteLink = inviteUrl
                        showAddHostShare = true

                        AnalyticsService.shared.logEvent("co_host_invite_generated", parameters: [
                            "event_id": viewModel.event.id,
                            "link_type": "appsflyer_onelink"
                        ])
                    } else {
                        // Fallback to simple format if URL construction fails
                        generatedInviteLink = "https://\(domain)/\(appId)?deep_link_value=/invite?secret=\(secret)&af_force_deeplink=true"
                        showAddHostShare = true
                    }

                    isGeneratingLink = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingLink = false
                    // TODO: Show error alert to user
                }
            }
        }
    }
}

// MARK: - Event Hero Section
struct EventHeroSection: View {
    let event: Event
    let confirmedGuests: [Guest]
    let pendingGuests: [Guest]
    let declinedGuests: [Guest]
    let scrollOffset: CGFloat

    // Calculate stretchy header effect
    private var imageHeight: CGFloat {
        let baseHeight: CGFloat = 574
        if scrollOffset > 0 {
            // Pull down - stretch the image
            return baseHeight + scrollOffset
        } else {
            // Scroll up - keep normal height
            return baseHeight
        }
    }

    private var imageOffset: CGFloat {
        // When pulling down, offset the image upward to keep it at the top
        scrollOffset > 0 ? -scrollOffset : 0
    }

    var body: some View {
        ZStack {
            // Background Cover Image with Gradient (stretchy header)
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Cover Image (uses effective cover which includes defaults)
                    CachedAsyncImage(url: URL(string: event.effectiveCoverImage)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Fallback gradient while loading
                        LinearGradient(
                            colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                    // Bottom gradient overlay for text
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: geometry.size.width, height: imageHeight)
                .offset(y: imageOffset)
            }

            // Blurred cover image for bottom overlay
            GeometryReader { geometry in
                CachedAsyncImage(url: URL(string: event.effectiveCoverImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .blur(radius: 20)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
                .frame(width: geometry.size.width, height: imageHeight)
                .offset(y: imageOffset)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.55),
                        .init(color: .black, location: 0.75),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Content Overlay
            VStack(spacing: 0) {
                Spacer()

                // Event Title
                Text(event.name)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.4)
                    .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 16)

                // Quick Action Buttons
                HStack(spacing: 8) {
                    NavigationLink(value: EventDetailsDestination.expenses(eventId: event.id)) {
                        QuickActionLabel(icon: "wallet-withdraw", title: L10n.expenses)
                    }

                    NavigationLink(value: EventDetailsDestination.agenda(eventId: event.id, eventDate: event.startDate)) {
                        QuickActionLabel(icon: "calendar-schedule", title: L10n.agenda)
                    }

                    NavigationLink(value: EventDetailsDestination.tasks(eventId: event.id)) {
                        QuickActionLabel(icon: "newspaper", title: L10n.tasks)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // RSVP Status Section
                RSVPStatusSection(
                    eventId: event.id,
                    confirmedGuests: confirmedGuests,
                    pendingGuests: pendingGuests,
                    declinedGuests: declinedGuests
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 574)
    }
}

// MARK: - Glass Effect Modifiers
// .clear with black tint at 0.25 opacity
struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .clear.tint(Color.black.opacity(0.12)).interactive(),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        } else {
            content
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .clear.tint(Color.black.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon - using custom assets from Figma
                Image(iconAssetName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.custom("SF Pro", size: 15))
                    .foregroundColor(.white)
                    .tracking(-0.23)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
        }
        .modifier(GlassButtonModifier())
    }

    private var iconAssetName: String {
        switch icon {
        case "wallet-withdraw": return "icon_wallet_withdraw"
        case "calendar-schedule": return "icon_calendar_schedule"
        case "newspaper": return "icon_newspaper"
        default: return "icon_newspaper"
        }
    }
}

// MARK: - Quick Action Label (for NavigationLink)
struct QuickActionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Image(iconAssetName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.custom("SF Pro", size: 15))
                .foregroundColor(.white)
                .tracking(-0.23)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .modifier(GlassButtonModifier())
    }

    private var iconAssetName: String {
        switch icon {
        case "wallet-withdraw": return "icon_wallet_withdraw"
        case "calendar-schedule": return "icon_calendar_schedule"
        case "newspaper": return "icon_newspaper"
        default: return "icon_newspaper"
        }
    }
}

// MARK: - Simple Flying Avatar Animation
struct FlyingLiquidAvatar: View {
    let guestName: String
    let fromPosition: CGPoint
    let toPosition: CGPoint
    let onComplete: () -> Void

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    private var initials: String {
        guestName.split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color(hex: "A17BF4"))
            .frame(width: 32, height: 32)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            )
            .scaleEffect(scale)
            .position(x: fromPosition.x + offset.width, y: fromPosition.y + offset.height)
            .onAppear {
                // Calculate the offset needed
                let dx = toPosition.x - fromPosition.x
                let dy = toPosition.y - fromPosition.y

                // Animate to destination with spring
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    offset = CGSize(width: dx, height: dy)
                }

                // Bounce effect at landing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        scale = 1.15
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }

                // Complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    onComplete()
                }
            }
    }
}

// MARK: - RSVP Animation State
@MainActor
class RSVPAnimationState: ObservableObject {
    @Published var flyingGuest: (name: String, from: RSVPStatus, to: RSVPStatus)?
    var previousGuests: [String: RSVPStatus] = [:] // guestId -> status
    var isInitialized = false

    func initializeIfNeeded(confirmed: [Guest], pending: [Guest], declined: [Guest]) {
        guard !isInitialized else { return }
        isInitialized = true

        for guest in confirmed { previousGuests[guest.id] = .confirmed }
        for guest in pending { previousGuests[guest.id] = .pending }
        for guest in declined { previousGuests[guest.id] = .declined }
    }

    func detectChanges(confirmed: [Guest], pending: [Guest], declined: [Guest]) {
        var currentGuests: [String: (status: RSVPStatus, name: String)] = [:]

        for guest in confirmed {
            currentGuests[guest.id] = (.confirmed, guest.name)
        }
        for guest in pending {
            currentGuests[guest.id] = (.pending, guest.name)
        }
        for guest in declined {
            currentGuests[guest.id] = (.declined, guest.name)
        }

        // Find guest that changed status
        for (guestId, current) in currentGuests {
            if let previousStatus = previousGuests[guestId], previousStatus != current.status {
                // Guest changed status!
                flyingGuest = (current.name, previousStatus, current.status)
                // Update previous state
                previousGuests = currentGuests.mapValues { $0.status }
                return
            }
        }

        // Update previous state
        previousGuests = currentGuests.mapValues { $0.status }
    }
}

// MARK: - RSVP Status Section
struct RSVPStatusSection: View {
    let eventId: String
    let confirmedGuests: [Guest]
    let pendingGuests: [Guest]
    let declinedGuests: [Guest]

    @StateObject private var animationState = RSVPAnimationState()
    @State private var columnPositions: [RSVPStatus: CGPoint] = [:]
    @State private var showFlyingAvatar = false

    // Track guest IDs for change detection
    private var allGuestSignature: String {
        let confirmed = confirmedGuests.map { "\($0.id):c" }.joined()
        let pending = pendingGuests.map { "\($0.id):p" }.joined()
        let declined = declinedGuests.map { "\($0.id):d" }.joined()
        return confirmed + pending + declined
    }

    var body: some View {
        HStack(spacing: 0) {
            // Going (Confirmed) - hide guest from DESTINATION during animation
            NavigationLink(value: EventDetailsDestination.guests(eventId: eventId, initialTab: .confirmed)) {
                GuestCounterColumn(
                    guests: confirmedGuests,
                    label: L10n.going,
                    hiddenGuestName: animationState.flyingGuest?.to == .confirmed ? animationState.flyingGuest?.name : nil
                )
            }
            .buttonStyle(.plain)
            .background(GeometryReader { geo in
                Color.clear.preference(key: ColumnPositionKey.self, value: [.confirmed: CGPoint(x: geo.frame(in: .named("rsvpSection")).midX, y: geo.frame(in: .named("rsvpSection")).midY - 10)])
            })

            Spacer()

            // Invited (Pending)
            NavigationLink(value: EventDetailsDestination.guests(eventId: eventId, initialTab: .pending)) {
                GuestCounterColumn(
                    guests: pendingGuests,
                    label: L10n.invited,
                    hiddenGuestName: animationState.flyingGuest?.to == .pending ? animationState.flyingGuest?.name : nil
                )
            }
            .buttonStyle(.plain)
            .background(GeometryReader { geo in
                Color.clear.preference(key: ColumnPositionKey.self, value: [.pending: CGPoint(x: geo.frame(in: .named("rsvpSection")).midX, y: geo.frame(in: .named("rsvpSection")).midY - 10)])
            })

            Spacer()

            // Not Going (Declined)
            NavigationLink(value: EventDetailsDestination.guests(eventId: eventId, initialTab: .declined)) {
                GuestCounterColumn(
                    guests: declinedGuests,
                    label: L10n.notGoing,
                    hiddenGuestName: animationState.flyingGuest?.to == .declined ? animationState.flyingGuest?.name : nil
                )
            }
            .buttonStyle(.plain)
            .background(GeometryReader { geo in
                Color.clear.preference(key: ColumnPositionKey.self, value: [.declined: CGPoint(x: geo.frame(in: .named("rsvpSection")).midX, y: geo.frame(in: .named("rsvpSection")).midY - 10)])
            })
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .coordinateSpace(name: "rsvpSection")
        .overlay {
            // Flying liquid avatar overlay - doesn't affect layout
            if showFlyingAvatar,
               let flying = animationState.flyingGuest,
               let fromPos = columnPositions[flying.from],
               let toPos = columnPositions[flying.to] {
                FlyingLiquidAvatar(
                    guestName: flying.name,
                    fromPosition: fromPos,
                    toPosition: toPos,
                    onComplete: {
                        showFlyingAvatar = false
                        animationState.flyingGuest = nil
                    }
                )
            }
        }
        .onPreferenceChange(ColumnPositionKey.self) { positions in
            columnPositions.merge(positions) { _, new in new }
        }
        .modifier(GlassCardModifier(cornerRadius: 12))
        .onChange(of: allGuestSignature) { oldValue, newValue in
            animationState.detectChanges(confirmed: confirmedGuests, pending: pendingGuests, declined: declinedGuests)
            if animationState.flyingGuest != nil && !columnPositions.isEmpty {
                showFlyingAvatar = true
            }
        }
        .onAppear {
            // Initialize previous state without triggering animation
            animationState.initializeIfNeeded(confirmed: confirmedGuests, pending: pendingGuests, declined: declinedGuests)
        }
    }
}

// Preference key to capture column positions
struct ColumnPositionKey: PreferenceKey {
    static var defaultValue: [RSVPStatus: CGPoint] = [:]
    static func reduce(value: inout [RSVPStatus: CGPoint], nextValue: () -> [RSVPStatus: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Guest Counter Column
struct GuestCounterColumn: View {
    let guests: [Guest]
    let label: String
    var labelFontSize: CGFloat = 15
    var labelTracking: CGFloat = -0.23
    var hiddenGuestName: String? = nil // Hide this guest during flying animation
    var onTap: (() -> Void)? = nil
    private let maxAvatars = 2

    // Filter out the hidden guest (the one that's flying)
    private var visibleGuests: [Guest] {
        if let hidden = hiddenGuestName {
            return guests.filter { $0.name != hidden }
        }
        return guests
    }

    private func getInitials(from name: String) -> String {
        name.split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: "A17BF4"),
            Color(hex: "8251EB"),
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    private var columnContent: some View {
        VStack(spacing: 10) {
            // Avatar Group or Empty Count
            HStack(spacing: -8) {
                if visibleGuests.isEmpty {
                    // Empty state - show 0 count with outline
                    Circle()
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("0")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                        )
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show avatars with initials (left to right, rightmost on top)
                    ForEach(Array(visibleGuests.prefix(maxAvatars).enumerated()), id: \.element.id) { index, guest in
                        Circle()
                            .fill(avatarColor(for: guest.name))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Text(getInitials(from: guest.name))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .zIndex(Double(index))
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Overflow count
                    if visibleGuests.count > maxAvatars {
                        Circle()
                            .fill(Color(hex: "F3F4F6"))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Text("+\(visibleGuests.count - maxAvatars)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "6B7280"))
                                    .contentTransition(.numericText())
                                )
                                .zIndex(Double(maxAvatars))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // Label
                Text(label)
                    .font(.custom("SF Pro", size: labelFontSize))
                    .foregroundColor(.white)
                    .tracking(labelTracking)
            }
            .frame(width: 84)
        }

    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    columnContent
                }
                .buttonStyle(.plain)
            } else {
                columnContent
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleGuests.map(\.id))
    }
}

// MARK: - Event Details Card
struct EventDetailsCard: View {
    let event: Event
    var onAddVenue: (() -> Void)?
    var onAddNote: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E5E5EA")
    }

    private var iconColor: Color {
        Color(hex: "8251EB")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date & Time
            HStack(spacing: 8) {
                Image("icon_calendar")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                Text(formatDate(event.startDate))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(textColor)
                    .tracking(-0.43)
            }

            // Divider
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .cornerRadius(8)

            // Location - show value or "Add venue" option
            if let venue = event.venue, !venue.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image("icon_map_marker")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(iconColor)
                        .frame(width: 24, height: 24)

                    Text(venue)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(textColor)
                        .tracking(-0.43)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }

                // Divider
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                    .cornerRadius(8)
            } else if let onAddVenue = onAddVenue {
                Button(action: onAddVenue) {
                    HStack(spacing: 8) {
                        Image("icon_map_marker")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(secondaryTextColor)
                            .frame(width: 24, height: 24)

                        Text("+ Add venue")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .tracking(-0.44)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                // Divider
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                    .cornerRadius(8)
            }

            // Notes/Custom Idea - show value or "Add note" option
            if let customIdea = event.customIdea, !customIdea.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image("icon_pin")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(iconColor)
                        .frame(width: 24, height: 24)

                    Text(customIdea)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(textColor)
                        .tracking(-0.43)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            } else if let onAddNote = onAddNote {
                Button(action: onAddNote) {
                    HStack(spacing: 8) {
                        Image("icon_pin")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(secondaryTextColor)
                            .frame(width: 24, height: 24)

                        Text("+ Add note")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .tracking(-0.44)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d HH:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview Invitation Button
struct PreviewInvitationButton: View {
    let event: Event
    let owner: User?
    let onEventUpdated: (Event) -> Void
    @State private var showInvitation = false

    var body: some View {
        Button {
            showInvitation = true
        } label: {
            HStack(spacing: 8) {
                Image("icon_mail")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(L10n.previewInvitation)
            }
            .foregroundColor(.rdPrimaryDark)
        }
        .rdButtonStyle(.secondary, size: .medium)
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $showInvitation) {
            NavigationStack {
                InvitationPreviewScreen(
                    event: event,
                    owner: owner,
                    isViewOnly: false,
                    onSave: { updatedEvent, localImage in
                        // Update the event and handle local image upload if needed
                        Task {
                            await handleSaveInvitation(updatedEvent: updatedEvent, localImage: localImage)
                        }
                    }
                )
            }
        }
    }

    private func handleSaveInvitation(updatedEvent: Event, localImage: Data?) async {
        var eventToSave = updatedEvent

        // If there's a local image, upload it first
        if let imageData = localImage {
            do {
                let storageService = DIContainer.shared.storageService
                guard let userId = DIContainer.shared.authService.currentUser?.id else {
                    onEventUpdated(eventToSave)
                    return
                }

                let filename = "cover_\(UUID().uuidString).jpg"
                let path = "users/\(userId)/covers/\(filename)"
                let uploadedUrl = try await storageService.uploadImage(data: imageData, path: path)
                eventToSave.coverImage = uploadedUrl
            } catch {
                // Failed to upload invitation cover
            }
        }

        // Save to backend
        do {
            let eventRepository = DIContainer.shared.eventRepository
            try await eventRepository.updateEvent(eventToSave)
            await MainActor.run {
                onEventUpdated(eventToSave)
            }
        } catch {
            // Error handled silently
        }
    }
}

// MARK: - Hosted By Section
struct HostedBySection: View {
    let event: Event
    let onAddHost: () -> Void
    let onSelectCoHost: (SharedUser) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color.black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E5E5EA")
    }

    private var addButtonBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    private var avatarStrokeColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    // Get host initials from owner name (comes from backend, always up-to-date)
    private var hostInitials: String {
        if let ownerName = event.ownerName, !ownerName.isEmpty {
            let parts = ownerName.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(ownerName.prefix(2)).uppercased()
        }
        // Fallback to "EH" for "Event Host"
        return "EH"
    }

    // Get host display name from backend (dynamic, updates when owner changes their name)
    private var hostDisplayName: String {
        if let ownerName = event.ownerName, !ownerName.isEmpty {
            return ownerName
        }
        return "Event Host"
    }

    // Get initials for a co-host
    private func coHostInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Text("HOSTED BY")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(secondaryTextColor)
                .tracking(-0.13)
                .textCase(.uppercase)
                .padding(.vertical, 8)

            // Host Card
            VStack(spacing: 8) {
                // Owner (Main Host) - showing initials like Figma design
                HStack(spacing: 8) {
                    // Avatar with initials
                    Circle()
                        .fill(Color.rdPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(hostInitials)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(avatarStrokeColor, lineWidth: 2))

                    Text(hostDisplayName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(textColor)
                        .tracking(-0.44)

                    Spacer()

                    // Owner badge
                    Text("Owner")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(dividerColor)
                        .cornerRadius(4)
                }

                // Co-hosts list
                ForEach(event.shared) { coHost in
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)

                    Button {
                        onSelectCoHost(coHost)
                    } label: {
                        HStack(spacing: 8) {
                            // Avatar with initials
                            Circle()
                                .fill(coHost.accepted ? Color.rdPrimary : Color(hex: "9C9CA6"))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(coHostInitials(coHost.name))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .overlay(Circle().stroke(avatarStrokeColor, lineWidth: 2))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(coHost.name.isEmpty ? "Pending Invite" : coHost.name)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(textColor)
                                    .tracking(-0.44)

                                if !coHost.accepted {
                                    Text("Invite pending")
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryTextColor)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Divider before add button
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                // Add Host Button
                Button(action: onAddHost) {
                    HStack(spacing: 8) {
                        // Plus Avatar with user-add icon
                        Circle()
                            .fill(addButtonBackground)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 14))
                                    .foregroundColor(secondaryTextColor)
                            )
                            .overlay(
                                Circle()
                                    .stroke(avatarStrokeColor, lineWidth: 2)
                            )

                        Text("+ Add host")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .tracking(-0.44)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Event Context Menu
struct EventContextMenu: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event
    let onEdit: () -> Void
    let onAddToCalendar: () -> Void
    let onMoveToDrafts: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.rdTextTertiary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header with Event Info
            HStack(spacing: 12) {
                // Event Thumbnail
                CachedAsyncImage(url: URL(string: event.effectiveCoverImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderGradient
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rdTextPrimary)
                        .lineLimit(2)

                    Text(formatEventDate(event.startDate))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.rdTextSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Menu Items
            VStack(spacing: 0) {
                MenuItemRow(icon: "icon_pencil_edit", title: L10n.editEvent, isCustomIcon: true, action: {
                    dismiss()
                    onEdit()
                })
                MenuItemRow(icon: "icon_calendar_add", title: L10n.addToCalendar, isCustomIcon: true, action: {
                    dismiss()
                    onAddToCalendar()
                })
                MenuItemRow(icon: "icon_file", title: L10n.moveToDrafts, isCustomIcon: true, action: {
                    dismiss()
                    onMoveToDrafts()
                })
                MenuItemRow(icon: "icon_bin", title: L10n.deleteEvent, isCustomIcon: true, isDestructive: true, action: {
                    dismiss()
                    onDelete()
                })
            }
            .padding(.top, 8)

            Spacer().frame(height: 20)
        }
        .background(Color.rdBackground)
        .presentationDragIndicator(.hidden)
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [Color.rdPrimary, Color.rdPrimaryDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Menu Item Row
struct MenuItemRow: View {
    let icon: String
    let title: String
    var isCustomIcon: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if isCustomIcon {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                    }
                }
                .foregroundColor(isDestructive ? .rdError : .rdTextPrimary)
                .frame(width: 28)

                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isDestructive ? .rdError : .rdTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model
@MainActor
class EventDetailsViewModel: ObservableObject {
    @Published var event: Event
    @Published var isLoading = false
    @Published var showEditEvent = false
    @Published var showDeleteConfirmation = false
    @Published var showShareSheet = false
    @Published var shouldDismiss = false

    // Alert states for Add to Calendar and Move to Drafts
    @Published var showCalendarAlert = false
    @Published var calendarAlertTitle = ""
    @Published var calendarAlertMessage = ""
    @Published var showMoveToDraftsAlert = false
    @Published var moveToDraftsAlertMessage = ""

    @Published var taskCount = 0
    @Published var hasBudget = false

    private let eventRepository: EventRepositoryProtocol
    private let notificationRepository: NotificationRepositoryProtocol
    private let taskRepository: TaskRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// Guests from AppState (single source of truth)
    var guests: [Guest] {
        appState?.guests(for: event.id) ?? []
    }

    init(event: Event, appState: AppState) {
        self.event = event
        self.appState = appState
        self.eventRepository = DIContainer.shared.eventRepository
        self.notificationRepository = DIContainer.shared.notificationRepository
        self.taskRepository = DIContainer.shared.taskRepository
        self.expenseRepository = DIContainer.shared.expenseRepository

        // Observe AppState guest changes for this event
        appState.$guestsByEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        Task {
            await loadGuests()
            await checkRateUsConditions()
        }
    }

    private func checkRateUsConditions() async {
        guard let events = appState?.events, !events.isEmpty else { return }
        guard let currentUserId = appState?.currentUser?.id else { return }

        await RateUsService.shared.checkAndShowIfNeeded(
            events: events,
            currentUserId: currentUserId,
            taskRepository: taskRepository,
            guestRepository: DIContainer.shared.guestRepository,
            expenseRepository: expenseRepository
        )
    }

    func loadGuests() async {
        isLoading = true
        defer { isLoading = false }
        await appState?.loadGuests(for: event.id)
    }


    var confirmedGuests: [Guest] {
        guests.filter { $0.rsvpStatus == .confirmed }
    }

    var pendingGuests: [Guest] {
        guests.filter { $0.rsvpStatus == .pending }
    }

    var declinedGuests: [Guest] {
        guests.filter { $0.rsvpStatus == .declined }
    }

    func editEvent() {
        showEditEvent = true
    }

    func addToCalendar() {
        let eventStore = EKEventStore()

        Task {
            // Check current authorization status first
            let status = EKEventStore.authorizationStatus(for: .event)

            switch status {
            case .notDetermined:
                // Request permission
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    if granted {
                        await saveEventToCalendar(eventStore: eventStore)
                    } else {
                        showCalendarDeniedAlert()
                    }
                } catch {
                    showCalendarErrorAlert()
                }

            case .fullAccess, .authorized:
                // Already have permission, save directly
                await saveEventToCalendar(eventStore: eventStore)

            case .denied, .restricted:
                // Permission denied, show alert to open Settings
                showCalendarDeniedAlert()

            case .writeOnly:
                // Write-only access, can still save
                await saveEventToCalendar(eventStore: eventStore)

            @unknown default:
                showCalendarErrorAlert()
            }
        }
    }

    private func saveEventToCalendar(eventStore: EKEventStore) async {
        do {
            let calendarEvent = EKEvent(eventStore: eventStore)
            calendarEvent.title = event.name
            calendarEvent.startDate = event.startDate
            calendarEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600)
            calendarEvent.location = event.venue
            calendarEvent.notes = event.customIdea
            calendarEvent.calendar = eventStore.defaultCalendarForNewEvents

            try eventStore.save(calendarEvent, span: .thisEvent)

            calendarAlertTitle = "Added to Calendar"
            calendarAlertMessage = "\"\(event.name)\" has been added to your calendar."
            showCalendarAlert = true
        } catch {
            showCalendarErrorAlert()
        }
    }

    private func showCalendarDeniedAlert() {
        calendarAlertTitle = "Calendar Access Required"
        calendarAlertMessage = "Please enable calendar access in Settings to add events."
        showCalendarAlert = true
    }

    private func showCalendarErrorAlert() {
        calendarAlertTitle = "Failed to Add"
        calendarAlertMessage = "Could not add event to calendar. Please try again."
        showCalendarAlert = true
    }

    func moveToDrafts() {
        Task {
            do {
                // Update event to mark as moved to draft
                var updatedEvent = event
                updatedEvent.isMovedToDraft = true
                try await eventRepository.updateEvent(updatedEvent)

                // Show success alert and dismiss after
                moveToDraftsAlertMessage = "\"\(event.name)\" has been moved to drafts."
                showMoveToDraftsAlert = true
            } catch {
                // Show error alert
                moveToDraftsAlertMessage = "Could not move event to drafts. Please try again."
                showMoveToDraftsAlert = true
            }
        }
    }

    func updateCoverImage(_ newCoverUrl: String) {
        Task {
            do {
                // Update UI immediately for instant feedback
                await MainActor.run {
                    var updatedEvent = event
                    updatedEvent.coverImage = newCoverUrl
                    self.event = updatedEvent
                }

                // Then update backend
                try await eventRepository.updateEvent(event)

                // Post notification to refresh home screen immediately (on main thread)
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("EventUpdated"), object: nil)
                }
            } catch {
                // Error handled silently
            }
        }
    }

    func removeCoHost(_ sharedUser: SharedUser) {
        Task {
            do {
                // Call backend to remove the shared user
                let grpcEvent = try await GRPCClientService.shared.removeSharedUser(
                    eventId: event.id,
                    secret: sharedUser.secret
                )

                // Update local event with the response
                let updatedEvent = Event(from: grpcEvent)
                await MainActor.run {
                    event = updatedEvent
                    // Also update AppState so the change is reflected everywhere
                    appState?.updateEvent(updatedEvent)
                }

                // Post notification to refresh home screen
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("EventUpdated"), object: nil)
                }

                AnalyticsService.shared.logEvent("co_host_removed", parameters: [
                    "event_id": event.id,
                    "co_host_name": sharedUser.name
                ])
            } catch {
                // Error handled silently
            }
        }
    }

    func updateCoHostAccessRole(_ sharedUser: SharedUser, to newRole: SharedUser.AccessRole) {
        // Update the local event's shared users list with new role
        if let index = event.shared.firstIndex(where: { $0.secret == sharedUser.secret }) {
            var updatedShared = event.shared
            updatedShared[index].accessRole = newRole
            event.shared = updatedShared
            appState?.updateEvent(event)
        }
    }

    func shareEvent() {
        showShareSheet = true
    }

    func deleteEvent() {
        showDeleteConfirmation = true
    }

    func confirmDeleteEvent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete all notifications associated with this event first
            await deleteEventNotifications()

            try await eventRepository.deleteEvent(id: event.id)
            shouldDismiss = true
        } catch {
            // Error handled silently
        }
    }

    private func deleteEventNotifications() async {
        do {
            // Delete all notifications grouped by eventId
            _ = try await notificationRepository.deleteNotificationsByGroup(groupField: .eventId, groupValue: event.id)
        } catch {
            // Error handled silently
        }
    }

    func updateEvent(_ updatedEvent: Event) {
        event = updatedEvent
    }

    func refreshEvent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let updatedEvent = try await eventRepository.getEvent(id: event.id)
            event = updatedEvent
            // Also update AppState so the change is reflected everywhere
            appState?.updateEvent(updatedEvent)
        } catch {
            // Refresh failed
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Navigation Destination
enum EventDetailsDestination: Hashable, Identifiable {
    case guests(eventId: String, initialTab: GuestTab? = nil)
    case tasks(eventId: String)
    case agenda(eventId: String, eventDate: Date)
    case expenses(eventId: String)
    case aiChat(event: Event)
    case contactUs

    var id: String {
        switch self {
        case .guests: return "guests"
        case .tasks: return "tasks"
        case .agenda: return "agenda"
        case .expenses: return "expenses"
        case .aiChat: return "aiChat"
        case .contactUs: return "contactUs"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EventDetailsView(event: Event.preview, appState: AppState())
    }
}
