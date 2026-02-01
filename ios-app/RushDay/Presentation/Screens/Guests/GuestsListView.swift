import SwiftUI
import UIKit
import Combine

// MARK: - Guest Tab Enum
@MainActor
enum GuestTab: String, CaseIterable, Identifiable, Sendable {
    case all
    case confirmed
    case pending
    case declined

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return L10n.all
        case .confirmed: return L10n.confirmed
        case .pending: return L10n.pending
        case .declined: return L10n.declined
        }
    }

    nonisolated var icon: String {
        switch self {
        case .all: return "person.2"
        case .confirmed: return "checkmark.circle"
        case .pending: return "clock"
        case .declined: return "xmark.circle"
        }
    }
}

// MARK: - Guests List View
struct GuestsListView: View {
    @StateObject private var viewModel: GuestsViewModel
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddGuest = false
    @State private var showImportContacts = false
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteSelectedConfirmation = false
    @State private var selectedGuestForEdit: Guest? = nil
    @State private var showNavTitle = false

    // Inline add guest state
    @State private var isAddingGuest = false
    @State private var newGuestName = ""
    @State private var newGuestEmail = ""
    @FocusState private var isNameFocused: Bool

    private let appState: AppState

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(hex: "F2F2F7")
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    init(eventId: String, appState: AppState, initialTab: GuestTab? = nil) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: GuestsViewModel(eventId: eventId, appState: appState, initialTab: initialTab))
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                HStack {
                    Text(viewModel.isMultiSelectEnabled ? "\(viewModel.selectedGuests.count) Selected" : L10n.guests)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content based on state - Shimmer logic:
                // Show shimmer while loading, empty state only when truly empty
                if viewModel.isLoading && viewModel.guests.isEmpty && !isAddingGuest {
                    // Loading with no data - show shimmer
                    ScrollView {
                        GuestsShimmerView()
                    }
                } else if !viewModel.isLoading && viewModel.guests.isEmpty && !isAddingGuest {
                    // Completely empty - show empty state (NOT in ScrollView for proper centering)
                    GuestEmptyView(
                        tab: viewModel.selectedTab,
                        onAddGuest: { startAddingGuest() },
                        onImportContacts: { showImportContacts = true }
                    )
                } else if viewModel.filteredGuests.isEmpty && !isAddingGuest {
                    // Has guests but filtered view is empty
                    VStack(spacing: 0) {
                        // Tab Bar
                        GuestTabBar(selectedTab: $viewModel.selectedTab, counts: viewModel.tabCounts)
                        // Empty state for filtered tab
                        FilteredEmptyView(tab: viewModel.selectedTab)
                    }
                } else {
                    // Has guests or is adding - show in ScrollView
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Tab Bar (only show when there are guests)
                            if !viewModel.guests.isEmpty {
                                GuestTabBar(selectedTab: $viewModel.selectedTab, counts: viewModel.tabCounts)
                            }

                            // Import From Contacts row (only on "All" tab) + Guest list
                            VStack(spacing: 0) {
                                if viewModel.selectedTab == .all {
                                    ImportFromContactsRow(onTap: { showImportContacts = true })
                                }

                                GuestCardView(
                                    guests: viewModel.filteredGuests,
                                    isAddingGuest: isAddingGuest,
                                    isMultiSelectEnabled: viewModel.isMultiSelectEnabled,
                                    selectedGuests: viewModel.selectedGuests,
                                    newGuestName: $newGuestName,
                                    isNameFocused: $isNameFocused,
                                    onGuestTapped: { guestId in
                                        if viewModel.isMultiSelectEnabled {
                                            viewModel.toggleGuestSelection(guestId)
                                        } else if let guest = viewModel.guests.first(where: { $0.id == guestId }) {
                                            selectedGuestForEdit = guest
                                        }
                                    },
                                    onGuestUpdated: viewModel.updateGuest,
                                    onGuestDeleted: viewModel.deleteGuest,
                                    onGuestInvite: { guest in
                                        viewModel.sendInvitation(to: guest)
                                    },
                                    onAddGuestSubmit: { submitNewGuest() },
                                    onAddGuestInfoTapped: { openGuestDetailSheet() }
                                )
                            }
                        }
                        .padding(.bottom, viewModel.isMultiSelectEnabled ? 100 : 100)
                    }
                }

                // Bottom Delete Bar (when in select mode with selections)
                if viewModel.isMultiSelectEnabled {
                    HStack {
                        Spacer()
                        Button(action: {
                            if !viewModel.selectedGuests.isEmpty {
                                showDeleteSelectedConfirmation = true
                            }
                        }) {
                            Text(L10n.delete)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(viewModel.selectedGuests.isEmpty ?
                                    (colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")) :
                                    Color(hex: "DB4F47"))
                        }
                        .disabled(viewModel.selectedGuests.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                }
            }

        }
        .overlay(alignment: .bottomTrailing) {
            // Floating Add Button
            if !viewModel.isMultiSelectEnabled {
                Button(action: { startAddingGuest() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(FloatingAddButtonStyle())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.isMultiSelectEnabled ? "\(viewModel.selectedGuests.count) Selected" : L10n.guests)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .opacity(showNavTitle ? 1 : 0)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isMultiSelectEnabled {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.isMultiSelectEnabled = false
                            viewModel.selectedGuests.removeAll()
                        }
                    }) {
                        Text(L10n.done)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(hex: "A17BF4"))
                    }
                } else if !viewModel.guests.isEmpty {
                    // Only show menu when there are guests
                    Menu {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.isMultiSelectEnabled = true
                            }
                        }) {
                            Label("Select Guests", systemImage: "checkmark.circle")
                        }

                        Button(role: .destructive, action: {
                            showDeleteAllConfirmation = true
                        }) {
                            Label {
                                Text("Delete all")
                            } icon: {
                                Image("icon_swipe_bin")
                                    .renderingMode(.template)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17))
                            .foregroundColor(textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .alert("Delete All Guests?", isPresented: $showDeleteAllConfirmation) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                viewModel.deleteAllGuests()
            }
        } message: {
            Text("All guests will be permanently deleted")
        }
        .alert("Delete \(viewModel.selectedGuests.count) Guests?", isPresented: $showDeleteSelectedConfirmation) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                viewModel.deleteSelectedGuests()
            }
        } message: {
            Text("All selected guests will be permanently deleted")
        }
        .sheet(isPresented: $showAddGuest, onDismiss: {
            // Clear inline add state when sheet is dismissed
            if isAddingGuest {
                cancelAddingGuest()
            }
        }) {
            AddGuestSheet(eventId: viewModel.eventId, initialName: newGuestName) { guest in
                viewModel.addGuest(guest)
                // Clear inline add state after successful add from sheet
                if isAddingGuest {
                    cancelAddingGuest()
                }
            }
        }
        .sheet(isPresented: $showImportContacts) {
            ImportContactsSheet(
                eventId: viewModel.eventId,
                existingGuestContactIds: viewModel.existingContactIds
            ) { guests in
                viewModel.addGuests(guests)
            }
        }
        .navigationDestination(item: $selectedGuestForEdit) { guest in
            GuestDetailsView(guest: guest, eventId: viewModel.eventId, appState: appState, onUpdate: viewModel.updateGuest, onDelete: { guestId in
                viewModel.deleteGuest(guestId)
                selectedGuestForEdit = nil
            })
        }
        .task {
            // Load fresh data from backend
            await viewModel.loadGuests()
        }
        .onChange(of: isNameFocused) { _, isFocused in
            // Auto-submit or cancel when focus is lost
            // But NOT if we're opening the detail sheet (showAddGuest will be true)
            if !isFocused && isAddingGuest && !showAddGuest {
                let trimmedName = newGuestName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    cancelAddingGuest()
                } else {
                    submitNewGuest()
                }
            }
        }
    }

    // MARK: - Inline Add Guest Helpers

    private func startAddingGuest() {
        newGuestName = ""
        newGuestEmail = ""
        isAddingGuest = true
        // Focus immediately for snappy feel
        isNameFocused = true
    }

    private func cancelAddingGuest() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAddingGuest = false
            newGuestName = ""
            newGuestEmail = ""
        }
        isNameFocused = false
    }

    private func submitNewGuest() {
        let trimmedName = newGuestName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            cancelAddingGuest()
            return
        }

        let guest = Guest(
            eventId: viewModel.eventId,
            name: trimmedName,
            email: nil,
            phoneNumber: nil,
            rsvpStatus: .pending,
            role: .guest
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.addGuest(guest)
        }
        cancelAddingGuest()
    }

    private func openGuestDetailSheet() {
        // Open the detail sheet with the current name pre-populated
        // Set showAddGuest FIRST so the onChange handler knows not to auto-submit
        showAddGuest = true
        isNameFocused = false
    }
}

// MARK: - Guest Tab Bar
struct GuestTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: GuestTab
    let counts: [GuestTab: Int]

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(GuestTab.allCases) { tab in
                    GuestTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        count: tab == .all ? (counts[tab] ?? 0) : 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Guest Tab Button (Underline Style)
struct GuestTabButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let tab: GuestTab
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    private var selectedColor: Color {
        Color(hex: "8251EB")
    }

    private var unselectedColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                HStack(spacing: 6) {
                    Text(tab.displayName)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? selectedColor : unselectedColor)

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "F2F2F7") : Color(hex: "F2F2F7"))
                            .frame(minWidth: 20, minHeight: 20)
                            .padding(.horizontal, 4)
                            .background(selectedColor)
                            .clipShape(Capsule())
                    }
                }

                // Underline indicator
                Rectangle()
                    .fill(selectedColor)
                    .frame(height: 4)
                    .cornerRadius(2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Import From Contacts Row
struct ImportFromContactsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let onTap: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var iconCircleBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Gray + icon in circle
                ZStack {
                    Circle()
                        .fill(iconCircleBackground)
                        .frame(width: 22, height: 22)
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryText)
                }

                Text("Import From Contacts")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(secondaryText)
                    .tracking(-0.44)

                Spacer()
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Guest List Content
struct GuestListContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let guests: [Guest]
    let isMultiSelectEnabled: Bool
    let selectedGuests: Set<String>
    let onGuestTapped: (String) -> Void
    let onGuestUpdated: (Guest) -> Void
    let onGuestDeleted: (String) -> Void
    let onGuestInvite: (Guest) -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "B9B9BB")
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(guests.enumerated()), id: \.element.id) { index, guest in
                GuestRowWithSwipe(
                    guest: guest,
                    isMultiSelectEnabled: isMultiSelectEnabled,
                    isSelected: selectedGuests.contains(guest.id),
                    onTapped: { onGuestTapped(guest.id) },
                    onStatusChanged: { status in
                        var updated = guest
                        updated.rsvpStatus = status
                        onGuestUpdated(updated)
                    },
                    onDelete: { onGuestDeleted(guest.id) },
                    onInvite: { onGuestInvite(guest) }
                )

                // Divider (not after last item)
                if index < guests.count - 1 {
                    dividerColor
                        .frame(height: 0.5)
                        .padding(.leading, 16)
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Guest Card View (with inline add support)
struct GuestCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let guests: [Guest]
    let isAddingGuest: Bool
    let isMultiSelectEnabled: Bool
    let selectedGuests: Set<String>
    @Binding var newGuestName: String
    var isNameFocused: FocusState<Bool>.Binding
    let onGuestTapped: (String) -> Void
    let onGuestUpdated: (Guest) -> Void
    let onGuestDeleted: (String) -> Void
    let onGuestInvite: (Guest) -> Void
    let onAddGuestSubmit: () -> Void
    let onAddGuestInfoTapped: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "B9B9BB")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Inline Add Guest Row (at top when adding)
            if isAddingGuest {
                AddGuestInlineRow(
                    name: $newGuestName,
                    isNameFocused: isNameFocused,
                    onSubmit: onAddGuestSubmit,
                    onInfoTapped: onAddGuestInfoTapped
                )
                .transition(.opacity.animation(.easeOut(duration: 0.15)))

                // Separator
                if !guests.isEmpty {
                    dividerColor
                        .frame(height: 0.5)
                        .padding(.leading, 16)
                }
            }

            // Existing Guests
            ForEach(Array(guests.enumerated()), id: \.element.id) { index, guest in
                GuestRowWithSwipe(
                    guest: guest,
                    isMultiSelectEnabled: isMultiSelectEnabled,
                    isSelected: selectedGuests.contains(guest.id),
                    onTapped: { onGuestTapped(guest.id) },
                    onStatusChanged: { status in
                        var updated = guest
                        updated.rsvpStatus = status
                        onGuestUpdated(updated)
                    },
                    onDelete: { onGuestDeleted(guest.id) },
                    onInvite: { onGuestInvite(guest) }
                )

                // Divider (not after last item)
                if index < guests.count - 1 {
                    dividerColor
                        .frame(height: 0.5)
                        .padding(.leading, 16)
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Add Guest Inline Row
struct AddGuestInlineRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var name: String
    var isNameFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onInfoTapped: () -> Void

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Name TextField
            TextField("Enter Guest Name", text: $name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textPrimary)
                .tracking(-0.44)
                .focused(isNameFocused)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit()
                }

            Spacer()

            // Info button
            Button(action: onInfoTapped) {
                Image(systemName: "info.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(hex: "A17BF4"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 57)
    }
}

// MARK: - Guest Row With Swipe Actions
struct GuestRowWithSwipe: View {
    @Environment(\.colorScheme) private var colorScheme
    let guest: Guest
    let isMultiSelectEnabled: Bool
    let isSelected: Bool
    let onTapped: () -> Void
    let onStatusChanged: (RSVPStatus) -> Void
    let onDelete: () -> Void
    let onInvite: () -> Void

    @State private var offset: CGFloat = 0
    private let buttonWidth: CGFloat = 60
    private let rowHeight: CGFloat = 57

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var unselectedCircleColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var inviteButtonBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    private var inviteButtonForeground: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var totalButtonWidth: CGFloat {
        buttonWidth * 2
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Swipe action buttons (behind the content)
            HStack(spacing: 0) {
                // Delete button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                    onDelete()
                }) {
                    VStack(spacing: 4) {
                        Image("icon_swipe_bin")
                            .renderingMode(.template)
                            .frame(width: 24, height: 24)
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: buttonWidth, height: 57)
                }
                .background(Color(hex: "DB4F47"))

                // Invite button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                    onInvite()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: 15, weight: .medium))
                        Text("Invite")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(inviteButtonForeground)
                    .frame(width: buttonWidth, height: 57)
                }
                .background(inviteButtonBackground)
            }
            .frame(width: totalButtonWidth)

            // Main content row
            HStack(spacing: 8) {
                if isMultiSelectEnabled {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color(hex: "8251EB") : unselectedCircleColor)
                        .font(.system(size: 22))
                }

                Text(guest.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textColor)
                    .tracking(-0.44)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .background(cardBackground)
            .offset(x: offset)
            .gesture(
                isMultiSelectEnabled ? nil : DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation < 0 {
                            // Swiping left - reveal buttons with slight resistance
                            let progress = min(1.0, abs(translation) / totalButtonWidth)
                            let resistedTranslation = translation * (1.0 - progress * 0.3)
                            offset = max(resistedTranslation, -totalButtonWidth)
                        } else if offset < 0 {
                            // Swiping right - hide buttons
                            let newOffset = offset + translation
                            offset = min(max(newOffset, -totalButtonWidth), 0)
                        }
                    }
                    .onEnded { value in
                        let velocity = value.velocity.width

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // Snap to open if past halfway or fast swipe left
                            if velocity < -300 || offset < -totalButtonWidth / 2 {
                                offset = -totalButtonWidth
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset != 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                } else {
                    onTapped()
                }
            }
        }
        .frame(height: rowHeight)
        .clipped()
    }
}

// MARK: - Guest Row
struct GuestRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let guest: Guest
    let isMultiSelectEnabled: Bool
    let isSelected: Bool
    let onTapped: () -> Void
    let onStatusChanged: (RSVPStatus) -> Void
    let onDelete: () -> Void
    let onInvite: () -> Void

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var unselectedCircleColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Selection indicator (only in multi-select mode)
            if isMultiSelectEnabled {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "8251EB") : unselectedCircleColor)
                    .font(.system(size: 22))
            }

            // Just the name - no avatar, no badges
            Text(guest.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textColor)
                .tracking(-0.44)

            Spacer()
        }
        .frame(height: 57)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapped)
    }
}

// MARK: - Swipeable Guest Row (for List context)
struct SwipeableGuestRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let guest: Guest
    let isMultiSelectEnabled: Bool
    let isSelected: Bool
    let onTapped: () -> Void
    let onStatusChanged: (RSVPStatus) -> Void
    let onDelete: () -> Void
    let onInvite: () -> Void

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var unselectedCircleColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var inviteButtonTint: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Selection indicator (only in multi-select mode)
            if isMultiSelectEnabled {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "8251EB") : unselectedCircleColor)
                    .font(.system(size: 22))
            }

            // Just the name - no avatar, no badges
            Text(guest.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textColor)
                .tracking(-0.44)

            Spacer()
        }
        .frame(height: 57)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapped)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete button (red)
            Button(role: .destructive, action: onDelete) {
                VStack(spacing: 4) {
                    Image("icon_swipe_bin")
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                    Text("Delete")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .tint(Color(hex: "DB4F47"))

            // Invite button (gray)
            Button(action: onInvite) {
                VStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 15, weight: .medium))
                    Text("Invite")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .tint(inviteButtonTint)
        }
    }
}

// MARK: - Guest Empty View
struct GuestEmptyView: View {
    @Environment(\.colorScheme) private var colorScheme
    let tab: GuestTab
    let onAddGuest: () -> Void
    let onImportContacts: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var iconCircleBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var titleText: Color {
        colorScheme == .dark ? Color(hex: "ABABAF") : Color(hex: "83828D")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Import From Contacts card
            Button(action: onImportContacts) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(iconCircleBackground)
                            .frame(width: 22, height: 22)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(secondaryText)
                    }

                    Text("Import From Contacts")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(secondaryText)
                        .tracking(-0.44)

                    Spacer()
                }
                .padding(16)
                .background(cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Centered content area
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    // Illustration - exact size from SVG: 138x134
                    Image("guests_empty_illustration")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 138, height: 134)

                    VStack(spacing: 0) {
                        Text("Build Your Guest List")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(titleText)
                            .tracking(-0.23)

                        Text("Add manually or import from contacts")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(secondaryText)
                            .tracking(-0.23)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(y: -45) // Offset up to account for FAB area
            }
        }
    }
}

// MARK: - Filtered Empty View (for filtered tabs with no matching guests)
struct FilteredEmptyView: View {
    @Environment(\.colorScheme) private var colorScheme
    let tab: GuestTab

    private var secondaryText: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var titleText: Color {
        colorScheme == .dark ? Color(hex: "ABABAF") : Color(hex: "83828D")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Illustration - exact size from SVG: 138x134
                Image("guests_empty_illustration")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 138, height: 134)

                VStack(spacing: 0) {
                    Text(emptyTitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(titleText)
                        .tracking(-0.23)

                    Text(emptySubtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(secondaryText)
                        .tracking(-0.23)
                }
                .multilineTextAlignment(.center)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(y: -45) // Offset up to account for FAB area
        }
    }

    private var emptyTitle: String {
        switch tab {
        case .all: return "Build Your Guest List"
        case .pending: return L10n.noPendingRSVPs
        case .confirmed: return L10n.noConfirmationsYet
        case .declined: return L10n.noDeclines
        }
    }

    private var emptySubtitle: String {
        switch tab {
        case .all: return "Add manually or import from contacts"
        case .pending: return L10n.noGuestsAwaiting
        case .confirmed: return L10n.confirmedGuestsAppear
        case .declined: return L10n.declinedGuestsAppear
        }
    }
}

// MARK: - Guest Delete Bar
struct GuestDeleteBar: View {
    let count: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("\(count) \(L10n.selected.lowercased())")
                .font(.rdBody())
                .foregroundColor(.rdTextPrimary)

            Spacer()

            Button(action: onDelete) {
                HStack(spacing: 6) {
                    Image("icon_swipe_bin")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(L10n.delete)
                }
                .font(.rdLabel())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.rdError)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.rdSurface)
        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
    }
}

// MARK: - Guest Details ViewModel

@MainActor
class GuestDetailsViewModel: ObservableObject {
    let guestId: String
    let eventId: String
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// Guest data - stored as @Published to trigger UI updates
    @Published var guest: Guest

    /// Returns true if the current user is the event owner or an accepted co-host (can edit/delete)
    var isOwnerOrCoHost: Bool {
        guard let appState = appState,
              let currentUserId = appState.currentUser?.id,
              let event = appState.events.first(where: { $0.id == eventId }) else {
            return false
        }
        let isOwner = currentUserId == event.ownerId
        let isAcceptedCoHost = event.shared.contains { $0.userId == currentUserId && $0.accepted }
        return isOwner || isAcceptedCoHost
    }

    init(guest: Guest, eventId: String, appState: AppState) {
        self.guestId = guest.id
        self.eventId = eventId
        self.appState = appState
        // Use _guest to set initial value without triggering objectWillChange
        self._guest = Published(initialValue: guest)

        // Observe AppState guest changes to update the guest property
        // Use .dropFirst() to skip the initial value emission
        appState.$guestsByEvent
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] guestsByEvent in
                guard let self = self else { return }
                if let updatedGuest = guestsByEvent[eventId]?.first(where: { $0.id == self.guestId }) {
                    self.guest = updatedGuest
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Guest Details View (Full Page)
struct GuestDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: GuestDetailsViewModel
    let onUpdate: (Guest) -> Void
    let onDelete: (String) -> Void

    @State private var showRemoveConfirmation = false
    @State private var showCopiedToast = false
    @State private var editedName: String = ""
    @State private var editedEmail: String = ""
    @State private var inviteLink: String = ""
    @State private var isLoadingInviteLink = false

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(hex: "F2F2F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    /// Convenience initializer that uses guest.eventId
    init(guest: Guest, appState: AppState, onUpdate: @escaping (Guest) -> Void, onDelete: @escaping (String) -> Void) {
        _viewModel = StateObject(wrappedValue: GuestDetailsViewModel(guest: guest, eventId: guest.eventId ?? "", appState: appState))
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    /// Full initializer with explicit eventId
    init(guest: Guest, eventId: String, appState: AppState, onUpdate: @escaping (Guest) -> Void, onDelete: @escaping (String) -> Void) {
        _viewModel = StateObject(wrappedValue: GuestDetailsViewModel(guest: guest, eventId: eventId, appState: appState))
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    private var isNameValid: Bool {
        !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEmailValid: Bool {
        let trimmedEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return false }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var hasChanges: Bool {
        editedName != viewModel.guest.name || editedEmail != (viewModel.guest.email ?? "")
    }

    private var canSave: Bool {
        isNameValid && hasChanges
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                mainContent
            }

            toastOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("", systemImage: "chevron.left") {
                    dismiss()
                }
                .tint(textPrimary)
            }
            ToolbarItem(placement: .principal) {
                Text("Guest Details")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveChangesIfNeeded()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canSave ? .rdAccent : .rdTextTertiary)
                }
                .disabled(!canSave)
            }
        }
        .alert("Remove Guest?", isPresented: $showRemoveConfirmation) {
            Button(L10n.cancel, role: .cancel) { }
            Button("Remove", role: .destructive) {
                onDelete(viewModel.guest.id)
                dismiss()
            }
        } message: {
            Text("This guest will be permanently removed from the event")
        }
        .onAppear {
            editedName = viewModel.guest.name
            editedEmail = viewModel.guest.email ?? ""
            inviteLink = viewModel.guest.inviteLink ?? Guest.generateInviteLink(id: viewModel.guest.id)
        }
        .task {
            await loadInviteLink()
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if showCopiedToast {
            VStack {
                Spacer()
                Text("Copied to clipboard")
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.23)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(hex: "9E9EAA"))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                    .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var mainContent: some View {
        VStack(spacing: 8) {
            // NAME Section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NAME")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)

                            TextField("Enter Guest Name", text: $editedName)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                        }

                        // EMAIL Section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EMAIL")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            TextField("Email Address", text: $editedEmail)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimary)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                        }

                        // INFO Section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INFO")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            VStack(spacing: 0) {
                                // Invitation Status
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Invitation status")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(textSecondary)
                                    Text(viewModel.guest.rsvpStatus.displayName)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)

                                Divider()
                                    .padding(.leading, 16)

                                // Invitation Link
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Invitation Link")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(textSecondary)
                                        Text(inviteLink)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(textSecondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Button(action: copyInviteLink) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 17))
                                            .foregroundColor(textSecondary)
                                    }
                                }
                                .padding(16)
                            }
                            .background(cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }

                        // Action Buttons Row
                        HStack(spacing: 16) {
                            // Share Link Button
                            Button(action: shareLink) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Link")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "8251EB"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "8251EB"), lineWidth: 1)
                                )
                            }

                            // Send via Mail Button
                            Button(action: sendMail) {
                                HStack {
                                    Image(systemName: "envelope")
                                    Text("Send via Mail")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isEmailValid ? Color(hex: "8251EB") : Color(hex: "9C9CA6").opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isEmailValid ? Color(hex: "8251EB") : Color(hex: "9C9CA6").opacity(0.2), lineWidth: 1)
                                )
                            }
                            .disabled(!isEmailValid)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Remove Guest Button (only for owners and co-hosts)
                        if viewModel.isOwnerOrCoHost {
                            Button(action: { showRemoveConfirmation = true }) {
                                Text("Remove Guest")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "DB4F47"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "DB4F47"), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

            Spacer(minLength: 40)
        }
    }

    private func loadInviteLink() async {
        guard !viewModel.eventId.isEmpty else { return }
        isLoadingInviteLink = true
        defer { isLoadingInviteLink = false }

        do {
            let invitation = try await GRPCClientService.shared.createGuestInvitation(
                guestId: viewModel.guest.id,
                eventId: viewModel.eventId
            )
            inviteLink = invitation.inviteLink
        } catch {
            // Keep fallback link
        }
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteLink
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCopiedToast = false
            }
        }
    }

    private func shareLink() {
        let activityVC = UIActivityViewController(activityItems: [inviteLink], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func sendMail() {
        guard isEmailValid else { return }
        let trimmedEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save changes before sending
        saveChangesIfNeeded()

        let subject = "Please Respond to the Invitation"
        let body = """
Hello \(trimmedName),
You are invited!
Please make sure to submit your response using the link below so your attendance can be confirmed.
\(inviteLink)

Thank you!
"""

        if let mailURL = URL(string: "mailto:\(trimmedEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(mailURL)
        }
    }

    private func sendInvitation() {
        // Share the invite link via system share sheet
        shareLink()
    }

    private func saveChangesIfNeeded() {
        guard hasChanges && isNameValid else { return }
        var updatedGuest = viewModel.guest
        updatedGuest.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedGuest.email = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        onUpdate(updatedGuest)
    }
}

// MARK: - Add Guest Sheet
struct AddGuestSheet: View {
    let eventId: String
    let initialName: String
    let onAdd: (Guest) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var email = ""
    @State private var isCreatingInvitation = false
    @FocusState private var focusedField: Field?

    private let guestRepository: GuestRepositoryProtocol = DIContainer.shared.guestRepository

    private enum Field {
        case name, email
    }

    init(eventId: String, initialName: String = "", onAdd: @escaping (Guest) -> Void) {
        self.eventId = eventId
        self.initialName = initialName
        self.onAdd = onAdd
        // Initialize name state with initialName
        _name = State(initialValue: initialName)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(hex: "F2F2F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var labelColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEmailValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return false }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var disabledButtonBorder: Color {
        Color(hex: "9C9CA6").opacity(0.2)
    }

    private var disabledButtonText: Color {
        Color(hex: "9C9CA6").opacity(0.2)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26Content
        } else {
            legacyContent
        }
    }

    @available(iOS 26.0, *)
    private var iOS26Content: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with glass effect
                RDSheetHeader(
                    title: "Guest Details",
                    canSave: isNameValid,
                    onDismiss: { dismiss() },
                    onSave: { addGuestAndDismiss() }
                )

                ScrollView {
                    formContent
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !initialName.isEmpty {
                    focusedField = .email
                } else {
                    focusedField = .name
                }
            }
        }
    }

    private var legacyContent: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    formContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addGuestAndDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isNameValid ? Color(hex: "8251EB") : textSecondary)
                    }
                    .disabled(!isNameValid)
                }
            }
            .onAppear {
                if !initialName.isEmpty {
                    focusedField = .email
                } else {
                    focusedField = .name
                }
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Guest Details")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(textPrimary)
                .tracking(0.38)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Form fields
            VStack(spacing: 8) {
                // Name Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(labelColor)
                        .tracking(-0.13)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)

                    TextField("Enter Guest Name", text: $name)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(textPrimary)
                        .tracking(-0.44)
                        .padding(16)
                        .frame(height: 56)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .email
                        }
                }

                // Email Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("EMAIL")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(labelColor)
                        .tracking(-0.13)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)

                    TextField("Email Address", text: $email)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(textPrimary)
                        .tracking(-0.44)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(16)
                        .frame(height: 56)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }

                // Action Buttons
                HStack(spacing: 16) {
                    // Share Link Button
                    Button(action: {
                        // Share link action - will be handled after adding
                        addGuestAndDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share Link")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(isNameValid ? Color(hex: "8251EB") : disabledButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isNameValid ? Color(hex: "8251EB") : disabledButtonBorder, lineWidth: 1)
                        )
                    }
                    .disabled(!isNameValid)

                    // Send via Mail Button
                    Button(action: {
                        // Send via mail - requires email
                        if isEmailValid && !isCreatingInvitation {
                            addGuestAndSendMail()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isCreatingInvitation {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color(hex: "8251EB"))
                            } else {
                                Image(systemName: "envelope")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(isCreatingInvitation ? "Creating..." : "Send via Mail")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(isNameValid && isEmailValid && !isCreatingInvitation ? Color(hex: "8251EB") : disabledButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isNameValid && isEmailValid && !isCreatingInvitation ? Color(hex: "8251EB") : disabledButtonBorder, lineWidth: 1)
                        )
                    }
                    .disabled(!isNameValid || !isEmailValid || isCreatingInvitation)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    private func addGuestAndDismiss() {
        guard isNameValid else { return }
        let guest = Guest(
            eventId: eventId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: nil,
            rsvpStatus: .pending,
            role: .guest
        )
        onAdd(guest)
        dismiss()
    }

    private func addGuestAndSendMail() {
        guard isNameValid && isEmailValid else { return }
        isCreatingInvitation = true

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let guest = Guest(
            eventId: eventId,
            name: trimmedName,
            email: trimmedEmail,
            phoneNumber: nil,
            rsvpStatus: .pending,
            role: .guest
        )

        Task {
            do {
                // First create the guest in backend (returns the guest ID)
                let guestId = try await guestRepository.addGuest(guest)

                // Then create the invitation to get the proper link
                let invitation = try await GRPCClientService.shared.createGuestInvitation(
                    guestId: guestId,
                    eventId: eventId
                )
                let inviteLink = invitation.inviteLink

                // Create guest with the backend ID and invite link
                let createdGuest = Guest(
                    id: guestId,
                    eventId: eventId,
                    name: trimmedName,
                    email: trimmedEmail,
                    rsvpStatus: .pending,
                    role: .guest,
                    inviteLink: inviteLink
                )

                // Update parent with the new guest
                await MainActor.run {
                    onAdd(createdGuest)
                    isCreatingInvitation = false

                    // Open mail composer
                    let subject = "Please Respond to the Invitation"
                    let body = """
Hello \(trimmedName),
You are invited!
Please make sure to submit your response using the link below so your attendance can be confirmed.
\(inviteLink)

Thank you!
"""

                    if let mailURL = URL(string: "mailto:\(trimmedEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        UIApplication.shared.open(mailURL)
                    }

                    dismiss()
                }
            } catch {
                // Fallback: still add guest and use client-side link
                await MainActor.run {
                    onAdd(guest)
                    isCreatingInvitation = false

                    let inviteLink = Guest.generateInviteLink(id: guest.id)
                    let subject = "Please Respond to the Invitation"
                    let body = """
Hello \(trimmedName),
You are invited!
Please make sure to submit your response using the link below so your attendance can be confirmed.
\(inviteLink)

Thank you!
"""

                    if let mailURL = URL(string: "mailto:\(trimmedEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        UIApplication.shared.open(mailURL)
                    }

                    dismiss()
                }
            }
        }
    }
}

// MARK: - Import Contacts Sheet
struct ImportContactsSheet: View {
    let eventId: String
    let onImport: ([Guest]) -> Void
    let existingGuestContactIds: Set<String>

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ImportContactsViewModel()
    @State private var searchText = ""

    init(eventId: String, existingGuestContactIds: Set<String> = [], onImport: @escaping ([Guest]) -> Void) {
        self.eventId = eventId
        self.existingGuestContactIds = existingGuestContactIds
        self.onImport = onImport
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                if !viewModel.contacts.isEmpty {
                    ContactSearchBar(text: $searchText, isSearching: $viewModel.isSearchMode)
                }

                // Content
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.error {
                        errorView(error)
                    } else if viewModel.contacts.isEmpty {
                        emptyView
                    } else {
                        contactsList
                    }
                }
            }
            .navigationTitle(L10n.addFromContacts)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.rdTextSecondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !viewModel.selectedContacts.isEmpty {
                    importButton
                }
            }
            .task {
                await viewModel.loadContacts()
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.filterContacts(query: newValue)
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L10n.loadingContacts)
                .font(.rdBody())
                .foregroundColor(.rdTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(.rdTextSecondary)

            Text(L10n.cannotAccessContacts)
                .font(.rdHeadline())
                .foregroundColor(.rdTextPrimary)

            Text(error)
                .font(.rdBody())
                .foregroundColor(.rdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(L10n.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.rdBody(.large))
            .foregroundColor(.rdPrimary)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            L10n.noContacts,
            systemImage: "person.crop.circle.badge.xmark",
            description: Text(L10n.noContactsFound)
        )
    }

    private var contactsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.displayedContacts.enumerated()), id: \.element.id) { index, contact in
                    let isAlreadyAdded = existingGuestContactIds.contains(contact.id)
                    let isSelected = viewModel.selectedContacts.contains(contact)

                    ContactRow(
                        contact: contact,
                        isSelected: isSelected,
                        isAlreadyAdded: isAlreadyAdded,
                        isFirst: index == 0,
                        isLast: index == viewModel.displayedContacts.count - 1
                    ) {
                        if !isAlreadyAdded {
                            viewModel.toggleContact(contact)
                        }
                    }

                    if index < viewModel.displayedContacts.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.rdSurface)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollBounceHaptic()
    }

    private var importButton: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedContacts.count) \(L10n.contactsSelected)")
                        .font(.rdBody())
                        .foregroundColor(.rdTextPrimary)
                }

                Spacer()

                RDGradientButton(
                    L10n.add,
                    height: 44,
                    cornerRadius: 10,
                    action: importSelectedContacts
                )
            }
            .padding(16)
            .background(Color.rdBackground)
        }
    }

    private func importSelectedContacts() {
        let guests = viewModel.selectedContacts.map { contact in
            Guest(
                eventId: eventId,
                contactId: contact.id,
                name: contact.displayName,
                email: contact.email,
                phoneNumber: contact.phoneNumber,
                rsvpStatus: .pending,
                role: .guest
            )
        }
        onImport(guests)
        dismiss()
    }
}

// MARK: - Import Contacts ViewModel
@MainActor
class ImportContactsViewModel: ObservableObject {
    @Published var contacts: [AppContact] = []
    @Published var filteredContacts: [AppContact] = []
    @Published var selectedContacts: Set<AppContact> = []
    @Published var isLoading = false
    @Published var isSearchMode = false
    @Published var error: String?

    private let contactsService: ContactsServiceProtocol

    var displayedContacts: [AppContact] {
        isSearchMode ? filteredContacts : contacts
    }

    init(contactsService: ContactsServiceProtocol = DIContainer.shared.contactsService) {
        self.contactsService = contactsService
    }

    func loadContacts() async {
        isLoading = true
        error = nil

        do {
            let granted = try await contactsService.requestAccess()
            if granted {
                contacts = try await contactsService.fetchContacts()
                filteredContacts = contacts
            } else {
                error = "Please allow access to your contacts in Settings to import guests."
            }
        } catch let contactError as ContactsServiceError {
            error = contactError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func filterContacts(query: String) {
        if query.isEmpty {
            isSearchMode = false
            filteredContacts = contacts
        } else {
            isSearchMode = true
            let lowercasedQuery = query.lowercased()
            filteredContacts = contacts.filter { contact in
                contact.displayName.lowercased().contains(lowercasedQuery) ||
                (contact.email?.lowercased().contains(lowercasedQuery) ?? false) ||
                (contact.phoneNumber?.contains(query) ?? false)
            }
        }
    }

    func toggleContact(_ contact: AppContact) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }
}

// MARK: - Contact Search Bar
struct ContactSearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.rdTextSecondary)

                TextField(L10n.searchContacts, text: $text)
                    .font(.rdBody())
                    .focused($isFocused)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.rdTextSecondary)
                    }
                }
            }
            .padding(10)
            .background(Color.rdSurface)
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Contact Row
struct ContactRow: View {
    let contact: AppContact
    let isSelected: Bool
    let isAlreadyAdded: Bool
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Contact info
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.rdBody())
                        .fontWeight(.medium)
                        .foregroundColor(.rdTextPrimary)

                    if let email = contact.email {
                        Text(email)
                            .font(.rdCaption())
                            .foregroundColor(.rdTextSecondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isAlreadyAdded {
                    Text(L10n.added)
                        .font(.rdCaption())
                        .foregroundColor(.rdTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.rdDivider)
                        .cornerRadius(16)
                } else {
                    Circle()
                        .fill(isSelected ? Color.rdPrimary : Color.rdPrimary.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: isSelected ? "checkmark" : "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isSelected ? .white : .rdPrimary)
                        )
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
        .opacity(isAlreadyAdded ? 0.6 : 1.0)
    }
}

// MARK: - View Model
@MainActor
class GuestsViewModel: ObservableObject {
    let eventId: String

    @Published var selectedTab: GuestTab = .all
    @Published var isLoading = true  // Start true to show shimmer on initial load
    @Published var isInitialized = false  // Tracks if data has been loaded at least once
    @Published var isMultiSelectEnabled = false
    @Published var selectedGuests: Set<String> = []

    private let guestRepository: GuestRepositoryProtocol
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// Guests from AppState (single source of truth)
    var guests: [Guest] {
        appState?.guests(for: eventId) ?? []
    }

    init(eventId: String, appState: AppState, initialTab: GuestTab? = nil) {
        self.eventId = eventId
        self.appState = appState
        self.guestRepository = DIContainer.shared.guestRepository
        if let initialTab = initialTab {
            self.selectedTab = initialTab
        }

        // Check if we have cached data - if so, no need to show shimmer
        let cachedGuests = appState.guests(for: eventId)
        if !cachedGuests.isEmpty {
            self.isLoading = false
            self.isInitialized = true
        }

        // Observe AppState guest changes for this event
        appState.$guestsByEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] guestsByEvent in
                guard let self = self else { return }
                // Trigger UI update when AppState guests change
                self.objectWillChange.send()
                // Reset loading state when cache is cleared (to show shimmer)
                // But NOT if already initialized (e.g. user deleted all items)
                let currentGuests = guestsByEvent[self.eventId] ?? []
                if currentGuests.isEmpty && !self.isInitialized {
                    self.isLoading = true
                }
            }
            .store(in: &cancellables)
    }

    var filteredGuests: [Guest] {
        switch selectedTab {
        case .all:
            return guests
        case .pending:
            return guests.filter { $0.rsvpStatus == .pending }
        case .confirmed:
            return guests.filter { $0.rsvpStatus == .confirmed }
        case .declined:
            return guests.filter { $0.rsvpStatus == .declined }
        }
    }

    var tabCounts: [GuestTab: Int] {
        [
            .all: guests.count,
            .confirmed: guests.filter { $0.rsvpStatus == .confirmed }.count,
            .pending: guests.filter { $0.rsvpStatus == .pending }.count,
            .declined: guests.filter { $0.rsvpStatus == .declined }.count
        ]
    }

    /// Contact IDs of guests that were imported from device contacts
    var existingContactIds: Set<String> {
        Set(guests.compactMap { $0.contactId })
    }

    func loadGuests() async {
        isLoading = true
        await appState?.loadGuests(for: eventId)
        // guests is a computed property from AppState, so no manual sync needed
        // Hide shimmer after AppState is updated
        isLoading = false
        isInitialized = true
    }

    func toggleGuestSelection(_ guestId: String) {
        if isMultiSelectEnabled {
            if selectedGuests.contains(guestId) {
                selectedGuests.remove(guestId)
            } else {
                selectedGuests.insert(guestId)
            }
        }
    }

    func addGuest(_ guest: Guest) {
        Task {
            do {
                let guestId = try await guestRepository.addGuest(guest)
                // Create guest with the returned ID from backend
                let addedGuest = Guest(
                    id: guestId,
                    eventId: guest.eventId,
                    userId: guest.userId,
                    contactId: guest.contactId,
                    name: guest.name,
                    email: guest.email,
                    phoneNumber: guest.phoneNumber,
                    photoURL: guest.photoURL,
                    rsvpStatus: guest.rsvpStatus,
                    role: guest.role,
                    plusOnes: guest.plusOnes,
                    dietaryRestrictions: guest.dietaryRestrictions,
                    notes: guest.notes,
                    inviteLink: guest.inviteLink,
                    invitedAt: guest.invitedAt,
                    respondedAt: guest.respondedAt,
                    createdAt: guest.createdAt,
                    updatedAt: guest.updatedAt
                )
                appState?.addGuest(addedGuest, eventId: eventId)
            } catch {
                // Error handled silently
            }
        }
    }

    func addGuests(_ newGuests: [Guest]) {
        Task {
            var addedGuests: [Guest] = []
            for guest in newGuests {
                do {
                    let guestId = try await guestRepository.addGuest(guest)
                    // Create guest with the returned ID from backend
                    let addedGuest = Guest(
                        id: guestId,
                        eventId: guest.eventId,
                        userId: guest.userId,
                        contactId: guest.contactId,
                        name: guest.name,
                        email: guest.email,
                        phoneNumber: guest.phoneNumber,
                        photoURL: guest.photoURL,
                        rsvpStatus: guest.rsvpStatus,
                        role: guest.role,
                        plusOnes: guest.plusOnes,
                        dietaryRestrictions: guest.dietaryRestrictions,
                        notes: guest.notes,
                        inviteLink: guest.inviteLink,
                        invitedAt: guest.invitedAt,
                        respondedAt: guest.respondedAt,
                        createdAt: guest.createdAt,
                        updatedAt: guest.updatedAt
                    )
                    addedGuests.append(addedGuest)
                } catch {
                    // Error handled silently
                }
            }
            if !addedGuests.isEmpty {
                appState?.addGuests(addedGuests, eventId: eventId)
            }
        }
    }

    func updateGuest(_ guest: Guest) {
        Task {
            do {
                try await guestRepository.updateGuest(guest)
                appState?.updateGuest(guest, eventId: eventId)
            } catch {
                // Error handled silently
            }
        }
    }

    func deleteGuest(_ guestId: String) {
        Task {
            do {
                try await guestRepository.removeGuest(id: guestId, eventId: eventId)
                appState?.removeGuest(id: guestId, eventId: eventId)
            } catch {
                // Error handled silently
            }
        }
    }

    func deleteSelectedGuests() {
        Task {
            var deletedIds = Set<String>()
            for guestId in selectedGuests {
                do {
                    try await guestRepository.removeGuest(id: guestId, eventId: eventId)
                    deletedIds.insert(guestId)
                } catch {
                    // Error handled silently
                }
            }
            if !deletedIds.isEmpty {
                appState?.removeGuests(ids: deletedIds, eventId: eventId)
            }
            selectedGuests.removeAll()
            isMultiSelectEnabled = false
        }
    }

    func deleteAllGuests() {
        Task {
            let allGuestIds = Set(guests.map { $0.id })
            for guestId in allGuestIds {
                do {
                    try await guestRepository.removeGuest(id: guestId, eventId: eventId)
                } catch {
                    // Error handled silently
                }
            }
            appState?.clearGuestCache(for: eventId)
        }
    }

    func sendInvitation(to guest: Guest) {
        Task {
            do {
                // Create invitation via backend to get the proper invite link
                let invitation = try await GRPCClientService.shared.createGuestInvitation(
                    guestId: guest.id,
                    eventId: eventId
                )
                let inviteLink = invitation.inviteLink

                // Present share sheet on main thread
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [inviteLink], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                // Fallback to client-side link generation if backend fails
                let inviteLink = guest.inviteLink ?? Guest.generateInviteLink(id: guest.id)
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [inviteLink], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            }
        }
    }

    /// Creates a guest invitation via backend and returns the invite link
    func createInvitation(for guest: Guest) async throws -> String {
        let invitation = try await GRPCClientService.shared.createGuestInvitation(
            guestId: guest.id,
            eventId: eventId
        )
        return invitation.inviteLink
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        GuestsListView(eventId: "preview-event-id", appState: AppState())
    }
}