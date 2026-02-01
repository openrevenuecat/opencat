import SwiftUI

// MARK: - Invitation Preview ViewModel
@MainActor
class InvitationPreviewViewModel: ObservableObject {
    @Published var event: Event
    @Published var owner: User
    @Published var coverImage: String?
    @Published var localCoverImage: Data?
    @Published var message: String
    @Published var isLoading = false
    @Published var showDiscardAlert = false
    @Published var showCoverPicker = false

    private let originalCoverImage: String?
    private let originalMessage: String?
    let isViewOnly: Bool

    init(
        event: Event,
        owner: User,
        localCoverImage: Data? = nil,
        isViewOnly: Bool = false
    ) {
        self.event = event
        self.owner = owner
        self.coverImage = event.coverImage
        self.originalCoverImage = event.coverImage
        self.localCoverImage = localCoverImage
        self.message = event.inviteMessage ?? ""
        self.originalMessage = event.inviteMessage
        self.isViewOnly = isViewOnly
    }

    var hasChanges: Bool {
        return originalCoverImage != coverImage ||
               originalMessage != (message.isEmpty ? nil : message) ||
               localCoverImage != nil
    }

    func onChangeCover(url: String?) {
        if let url = url {
            coverImage = url
            localCoverImage = nil
        }
    }

    func save() -> (event: Event, localImage: Data?) {
        var updatedEvent = event
        updatedEvent.coverImage = coverImage
        updatedEvent.inviteMessage = message.isEmpty ? nil : message
        return (event: updatedEvent, localImage: localCoverImage)
    }
}

// MARK: - Invitation Preview Screen
struct InvitationPreviewScreen: View {
    @StateObject private var viewModel: InvitationPreviewViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: ((Event, Data?) -> Void)?

    init(
        event: Event,
        owner: User? = nil,
        localCoverImage: Data? = nil,
        isViewOnly: Bool = false,
        onSave: ((Event, Data?) -> Void)? = nil
    ) {
        let hostUser = owner ?? User(
            id: event.ownerId,
            name: L10n.eventHost,
            email: ""
        )
        _viewModel = StateObject(wrappedValue: InvitationPreviewViewModel(
            event: event,
            owner: hostUser,
            localCoverImage: localCoverImage,
            isViewOnly: isViewOnly
        ))
        self.onSave = onSave
    }

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var imagesButton: some View {
        let button = Button("", systemImage: "photo.on.rectangle") {
            viewModel.showCoverPicker = true
        }
        if #available(iOS 26.0, *) {
            button.glassEffect(.regular.interactive())
        } else {
            button
        }
    }

    private var closeButton: some View {
        RDCloseButton { handleClose() }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.rdBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section - sizes itself based on content
                        InvitationHeroSection(
                            viewModel: viewModel,
                            screenHeight: geometry.size.height
                        )

                        // Content Section
                        VStack(spacing: 24) {
                            // Message Section
                            InvitationMessageSection(viewModel: viewModel)

                            // Host Section
                            InvitationHostSection(owner: viewModel.owner)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, !viewModel.isViewOnly ? 120 : 40)
                    }
                }
                .scrollBounceHaptic()
                .ignoresSafeArea(edges: .top)

                // Bottom Save Button (fixed at bottom)
                if !viewModel.isViewOnly {
                    VStack {
                        Spacer()
                        InvitationBottomBar {
                            handleSave()
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
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
                    if !viewModel.isViewOnly {
                        ToolbarItem {
                            imagesButton
                        }
                        if #available(iOS 26.0, *) {
                            ToolbarSpacer(.fixed)
                        }
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
                            if !viewModel.isViewOnly {
                                Button(action: { viewModel.showCoverPicker = true }) {
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
                            }

                            Button(action: { handleClose() }) {
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
        .alert(L10n.unsavedChanges, isPresented: $viewModel.showDiscardAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.discard, role: .destructive) {
                dismiss()
            }
            Button(L10n.save) {
                handleSave()
            }
        } message: {
            Text(L10n.whatWouldYouLikeToDo)
        }
        .sheet(isPresented: $viewModel.showCoverPicker) {
            CoverSelectionSheet(selectedCoverUrl: Binding(
                get: { viewModel.coverImage },
                set: { viewModel.onChangeCover(url: $0) }
            ))
            .presentationDetents([.height(340), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleClose() {
        if viewModel.hasChanges {
            viewModel.showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func handleSave() {
        let result = viewModel.save()
        onSave?(result.event, result.localImage)
        dismiss()
    }
}

// MARK: - Invitation Hero Section
struct InvitationHeroSection: View {
    @ObservedObject var viewModel: InvitationPreviewViewModel
    let screenHeight: CGFloat

    // Cover image area height (Figma: ~607pt on 852pt screen = 71%)
    private var coverImageHeight: CGFloat {
        let fullHeight = UIScreen.main.bounds.height
        return max(fullHeight * 0.71, 500)
    }

    @ViewBuilder
    private var coverImageView: some View {
        if let localImage = viewModel.localCoverImage,
           let uiImage = UIImage(data: localImage) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            let coverUrl = (viewModel.coverImage?.isEmpty == false) ? viewModel.coverImage! : AppConfig.shared.defaultCoverUrl

            CachedAsyncImage(url: URL(string: coverUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                LinearGradient(
                    colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .id(coverUrl)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed-height cover image area with title
            ZStack(alignment: .bottom) {
                // Stretchy cover image
                GeometryReader { geometry in
                    let scrollOffset = geometry.frame(in: .global).minY
                    let height = scrollOffset > 0 ? coverImageHeight + scrollOffset : coverImageHeight
                    let offset = scrollOffset > 0 ? -scrollOffset : CGFloat(0)

                    coverImageView
                        .frame(width: geometry.size.width, height: height)
                        .clipped()
                        .offset(y: offset)
                }

                // Blurred image layer behind title (Figma: 334pt)
                GeometryReader { blurGeometry in
                    coverImageView
                        .frame(width: blurGeometry.size.width, height: coverImageHeight)
                        .blur(radius: 8)
                        .clipped()
                }
                .frame(height: 450)
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.5), location: 0.3),
                            .init(color: .black, location: 0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Gradient overlay - fades image into background
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.clear, location: 0.45),
                        .init(color: Color.rdBackground.opacity(0.5), location: 0.65),
                        .init(color: Color.rdBackground, location: 0.93)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 450)

                // Title text pinned to bottom of image
                VStack(spacing: 8) {
                    Text("\(viewModel.owner.displayName ?? L10n.host) invites you to")
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.44)
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)

                    Text(viewModel.event.name)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .tracking(0.38)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 220)
            }
            .frame(height: coverImageHeight)

            // Card OUTSIDE the fixed-height image area so it's never clipped
            InvitationEventDetailsCard(event: viewModel.event)
                .padding(.horizontal, 16)
                .offset(y: -196)
                .padding(.bottom, -196)
        }
    }
}

// MARK: - Event Details Card
struct InvitationEventDetailsCard: View {
    let event: Event
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E").opacity(0.8) : Color.white.opacity(0.7)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var dividerColor: Color {
        Color(hex: "9C9CA6").opacity(0.2)
    }

    private var hasVenue: Bool {
        if let venue = event.venue, !venue.isEmpty { return true }
        return false
    }

    private var hasCustomIdea: Bool {
        if let customIdea = event.customIdea, !customIdea.isEmpty { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            // Date
            HStack(spacing: 8) {
                Image("icon_calendar")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.rdPrimaryDark)
                    .frame(width: 24, height: 24)

                Text(formatDate(event.startDate))
                    .font(.system(size: 17))
                    .foregroundColor(textColor)
                    .tracking(-0.43)

                Spacer()
            }

            // Divider after date
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Venue
            HStack(alignment: .top, spacing: 8) {
                Image("icon_map_marker")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.rdPrimaryDark)
                    .frame(width: 24, height: 24)

                if let venue = event.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.system(size: 17))
                        .foregroundColor(textColor)
                        .tracking(-0.43)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No location added")
                        .font(.system(size: 17))
                        .foregroundColor(.rdTextTertiary)
                        .tracking(-0.43)
                }

                Spacer()
            }

            // Divider after venue
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Custom Idea/Notes
            HStack(alignment: .top, spacing: 8) {
                Image("icon_pin")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.rdPrimaryDark)
                    .frame(width: 24, height: 24)

                if let customIdea = event.customIdea, !customIdea.isEmpty {
                    Text(customIdea)
                        .font(.system(size: 17))
                        .foregroundColor(textColor)
                        .tracking(-0.43)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No notes added")
                        .font(.system(size: 17))
                        .foregroundColor(.rdTextTertiary)
                        .tracking(-0.43)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Invitation Message Section
struct InvitationMessageSection: View {
    @ObservedObject var viewModel: InvitationPreviewViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isGenerating = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E").opacity(0.8) : Color.white.opacity(0.7)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                viewModel.isViewOnly ? L10n.noMessageYet : L10n.enterMessageForGuests,
                text: $viewModel.message,
                axis: .vertical
            )
            .font(.system(size: 17))
            .tracking(-0.44)
            .foregroundColor(viewModel.message.isEmpty ? .rdTextTertiary : .rdTextPrimary)
            .lineLimit(3...)
            .disabled(viewModel.isViewOnly || isGenerating)
            .focused($isFocused)

            // AI Generate Button (only show in edit mode)
            if !viewModel.isViewOnly {
                Button {
                    generateInviteMessage()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                    } else {
                        Image("icon_ai_generate")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.rdPrimaryDark)
                    }
                }
                .disabled(isGenerating)
            }
        }
        .padding(16)
        .frame(minHeight: 102)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func generateInviteMessage() {
        isGenerating = true

        Task {
            do {
                let generatedMessage = try await GRPCClientService.shared.generateInviteMessage(
                    eventId: viewModel.event.id
                )
                await MainActor.run {
                    viewModel.message = generatedMessage
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Invitation Host Section
struct InvitationHostSection: View {
    let owner: User
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E").opacity(0.8) : Color.white.opacity(0.7)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var headerColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Text("HOSTED BY")
                .font(.system(size: 13))
                .tracking(-0.13)
                .foregroundColor(headerColor)
                .padding(.vertical, 8)

            // Host Card
            HStack(spacing: 8) {
                // Avatar with white border
                Circle()
                    .fill(Color.rdPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Group {
                            if let photoURL = owner.photoURL, !photoURL.isEmpty {
                                CachedAsyncImage(url: URL(string: photoURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ownerInitials
                                }
                                .clipShape(Circle())
                                .id(photoURL)
                            } else {
                                ownerInitials
                            }
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )

                // Name
                Text(owner.displayName ?? L10n.host)
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.44)
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var ownerInitials: some View {
        Text(owner.initials ?? "H")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
    }
}

// MARK: - Invitation Bottom Bar
struct InvitationBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    private var barBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.rdBackground
    }

    private var buttonBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    private var buttonTextColor: Color {
        Color.rdPrimaryDark
    }

    private var buttonBorderColor: Color {
        Color.rdPrimaryDark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color(hex: "545456").opacity(0.34))
                .frame(height: 0.5)

            // Button container
            Button(action: action) {
                Text(L10n.save)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(buttonBorderColor, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(barBackground)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview
#Preview {
    InvitationPreviewScreen(
        event: .preview,
        owner: User(
            id: "user_123",
            name: "Timothe Cook",
            email: "host@example.com",
            photoUrl: nil
        )
    )
}
