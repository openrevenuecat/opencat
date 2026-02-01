import SwiftUI
import UIKit
import Combine

// MARK: - Agenda List View
struct AgendaListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AgendaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddItem = false
    @State private var showDeleteSelectedAlert = false
    @State private var showDeleteAllAlert = false

    private let eventId: String

    init(eventId: String, eventDate: Date) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: AgendaViewModel(eventId: eventId, eventDate: eventDate, appState: nil))
    }

    // Title text
    private var titleText: String {
        if viewModel.isMultiSelectEnabled {
            if viewModel.selectedItems.isEmpty {
                return "Select Activity"
            } else {
                return "\(viewModel.selectedItems.count) Selected"
            }
        }
        return "Agenda"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom header with SF Pro Rounded
                HStack {
                    Text(titleText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(UIColor.label))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content - Shimmer logic:
                // Show shimmer while loading
                if viewModel.isLoading {
                    // Loading - show shimmer
                    ScrollView {
                        AgendaShimmerView()
                    }
                } else if viewModel.agendaItems.isEmpty {
                    AgendaEmptyView(onAddItem: { showAddItem = true })
                } else {
                    AgendaScrollContent(
                        items: viewModel.agendaItems,
                        eventDate: viewModel.eventDate,
                        isMultiSelectEnabled: viewModel.isMultiSelectEnabled,
                        selectedItems: viewModel.selectedItems,
                        onItemTapped: viewModel.toggleItemSelection,
                        onItemUpdated: viewModel.updateItem,
                        onItemDeleted: viewModel.deleteItem,
                        onReorder: viewModel.reorderItems,
                        onScrollOffsetChanged: { _ in },
                        onLongPress: viewModel.activateSelectMode
                    )
                }

                // Bottom toolbar when in select mode
                if viewModel.isMultiSelectEnabled {
                    SelectModeToolbar(
                        isAllSelected: viewModel.selectedItems.count == viewModel.agendaItems.count && !viewModel.agendaItems.isEmpty,
                        hasSelection: !viewModel.selectedItems.isEmpty,
                        showCompleteButton: false,
                        canComplete: false,
                        onSelectAll: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                if viewModel.selectedItems.count == viewModel.agendaItems.count {
                                    viewModel.selectedItems.removeAll()
                                } else {
                                    viewModel.selectedItems = Set(viewModel.agendaItems.map { $0.id })
                                }
                            }
                        },
                        onDelete: {
                            if !viewModel.selectedItems.isEmpty {
                                showDeleteSelectedAlert = true
                            }
                        },
                        onComplete: nil
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isMultiSelectEnabled)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .tint(.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.agendaItems.isEmpty {
                        if viewModel.isMultiSelectEnabled {
                            SelectModeCheckmarkButton(hasSelection: !viewModel.selectedItems.isEmpty) {
                                viewModel.isMultiSelectEnabled = false
                                viewModel.selectedItems.removeAll()
                            }
                            .id(viewModel.selectedItems.count)
                        } else {
                            Menu {
                                Button {
                                    viewModel.isMultiSelectEnabled = true
                                } label: {
                                    Label("Select Activities", systemImage: "checkmark.circle")
                                }
                                Button(role: .destructive) {
                                    showDeleteAllAlert = true
                                } label: {
                                    Label {
                                        Text("Delete All")
                                    } icon: {
                                        Image("icon_bin_red")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .fontWeight(.semibold)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Only show floating button when NOT in select mode
                if !viewModel.agendaItems.isEmpty && !viewModel.isMultiSelectEnabled {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(FloatingAddButtonStyle())
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddAgendaItemSheet(
                    eventId: viewModel.eventId,
                    eventDate: viewModel.eventDate,
                    nextOrder: viewModel.agendaItems.count,
                    existingItems: viewModel.agendaItems,
                    onAdd: { item in
                        viewModel.addItem(item)
                    },
                    onReplace: { conflictId, newItem in
                        viewModel.replaceItem(conflictId: conflictId, with: newItem)
                    }
                )
            }
            .onAppear {
                // Check cache state and set loading appropriately on each visit
                viewModel.setAppState(appState)
            }
            .task {
                // Load fresh data from backend
                await viewModel.loadAgenda()
            }

        }
        .alert("Delete \(viewModel.selectedItems.count) Activities?", isPresented: $showDeleteSelectedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedItems()
            }
        } message: {
            Text("All selected activities will be permanently deleted")
        }
        .alert("Delete All Activities?", isPresented: $showDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllItems()
            }
        } message: {
            Text("All activities will be permanently deleted")
        }
    }
}

// MARK: - Select Mode Delete Bar
/// Bottom bar with Delete button matching Figma design 301:34746
struct AgendaSelectModeDeleteBar: View {
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        Color(hex: "9C9CA6").opacity(0.4)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(borderColor)
                .frame(height: 0.33)

            // Delete button
            Button(action: onDelete) {
                Text("Delete")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.44)
                    .foregroundColor(Color(hex: "DB4F47")) // warning color
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Agenda Scroll Content
/// Renders the agenda items grouped by date with scroll tracking
struct AgendaScrollContent: View {
    let items: [AgendaItem]
    let eventDate: Date
    let isMultiSelectEnabled: Bool
    let selectedItems: Set<String>
    let onItemTapped: (String) -> Void
    let onItemUpdated: (AgendaItem) -> Void
    let onItemDeleted: (String) -> Void
    let onReorder: ([String]) -> Void
    let onScrollOffsetChanged: (CGFloat) -> Void
    let onLongPress: (String) -> Void  // Long-press to activate select mode

    @Environment(\.colorScheme) private var colorScheme

    // Group items by date (day) from their startTime
    private var groupedItems: [(date: Date, items: [AgendaItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.startTime)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, items: $0.value.sorted { $0.startTime < $1.startTime }) }
    }

    // Format date for section header
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today,' d MMMM, yyyy"
        } else {
            formatter.dateFormat = "EEEE, d MMMM, yyyy"
        }
        return formatter.string(from: date)
    }

    // Section header color - purple for today, gray for other dates
    private func dateHeaderColor(for date: Date) -> Color {
        Calendar.current.isDateInToday(date) ? Color(hex: "8251EB") : Color(hex: "9E9EAA")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Date sections - group items by their actual date (24px top padding per Figma)
                ForEach(groupedItems, id: \.date) { group in
                    // Date section header
                    Text(formatDate(group.date))
                        .font(.system(size: 20, weight: .medium))
                        .tracking(-0.24)
                        .foregroundColor(dateHeaderColor(for: group.date))
                        .textCase(.none)
                        .padding(.horizontal, 16)
                        .padding(.top, group.date == groupedItems.first?.date ? 0 : 8)

                    // Agenda items for this date
                    if isMultiSelectEnabled {
                        AgendaSelectModeList(
                            items: group.items,
                            selectedItems: selectedItems,
                            onItemTapped: onItemTapped
                        )
                    } else {
                        AgendaTimelineList(
                            items: group.items,
                            isMultiSelectEnabled: isMultiSelectEnabled,
                            selectedItems: selectedItems,
                            onItemTapped: onItemTapped,
                            onItemDeleted: onItemDeleted,
                            onReorder: onReorder,
                            onLongPress: onLongPress
                        )
                    }
                }
            }
            .padding(.top, 8) // Space below title per Figma (py-24 minus header padding)
            .padding(.bottom, 100) // Space for floating button / delete bar
            .background(
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                        onScrollOffsetChanged(newValue)
                    }
                }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Agenda Select Mode List
/// List view for select mode with radio buttons (no timeline dots) matching Figma design 301:34632
struct AgendaSelectModeList: View {
    let items: [AgendaItem]
    let selectedItems: Set<String>
    let onItemTapped: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                AgendaSelectModeItemRow(
                    item: item,
                    isSelected: selectedItems.contains(item.id),
                    onTapped: { onItemTapped(item.id) }
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Agenda Select Mode Item Row
/// Single agenda item row for select mode with radio button matching Figma design
struct AgendaSelectModeItemRow: View {
    let item: AgendaItem
    let isSelected: Bool
    let onTapped: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Background: white normally, gray when selected (Figma: rgba(156,156,166,0.2))
    private var cardBackground: Color {
        if isSelected {
            return Color(hex: "9C9CA6").opacity(0.2)
        }
        return colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    private var timeColor: Color {
        Color(hex: "9E9EAA")
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Radio button - circle outline when unselected, filled checkmark when selected
            ZStack {
                if isSelected {
                    // Filled checkmark circle (Figma: purple filled with white checkmark)
                    Circle()
                        .fill(Color(hex: "8251EB"))
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    // Empty circle outline
                    Circle()
                        .stroke(Color(hex: "9C9CA6").opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .frame(width: 24, height: 24)

            // Content card
            VStack(alignment: .leading, spacing: 4) {
                // Time range
                Text(formatTimeRange())
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.44)
                    .foregroundColor(timeColor)

                // Title
                Text(item.title)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.44)
                    .foregroundColor(titleColor)
                    .lineLimit(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .cornerRadius(12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapped)
    }

    private func formatTimeRange() -> String {
        let formatter = DateFormatter()

        if let endTime = item.endTime {
            // Check if both times are in the same AM/PM period
            let calendar = Calendar.current
            let startHour = calendar.component(.hour, from: item.startTime)
            let endHour = calendar.component(.hour, from: endTime)
            let startIsAM = startHour < 12
            let endIsAM = endHour < 12

            if startIsAM == endIsAM {
                // Same period - show AM/PM only at the end
                formatter.dateFormat = "h:mm"
                let start = formatter.string(from: item.startTime)
                formatter.dateFormat = "h:mm a"
                let end = formatter.string(from: endTime)
                return "\(start) - \(end)"
            } else {
                // Different periods - show both AM/PM
                formatter.dateFormat = "h:mm a"
                let start = formatter.string(from: item.startTime)
                let end = formatter.string(from: endTime)
                return "\(start) - \(end)"
            }
        }

        // No end time - just show start time with AM/PM
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: item.startTime)
    }
}

// MARK: - Agenda Timeline List
/// Renders agenda items with vertical timeline indicator
struct AgendaTimelineList: View {
    let items: [AgendaItem]
    let isMultiSelectEnabled: Bool
    let selectedItems: Set<String>
    let onItemTapped: (String) -> Void
    let onItemDeleted: (String) -> Void
    let onReorder: ([String]) -> Void
    let onLongPress: (String) -> Void  // Callback for long-press to activate select mode

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                AgendaTimelineItemRow(
                    item: item,
                    isLast: index == items.count - 1,
                    isMultiSelectEnabled: isMultiSelectEnabled,
                    isSelected: selectedItems.contains(item.id),
                    onTapped: { onItemTapped(item.id) },
                    onDelete: { onItemDeleted(item.id) },
                    onLongPress: { onLongPress(item.id) }
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Agenda Timeline Item Row
/// Single agenda item with timeline dot and connecting line matching Figma design
struct AgendaTimelineItemRow: View {
    let item: AgendaItem
    let isLast: Bool
    let isMultiSelectEnabled: Bool
    let isSelected: Bool
    let onTapped: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void  // Long-press to activate select mode

    @Environment(\.colorScheme) private var colorScheme

    // Check if item is currently active (now is between start and end time)
    private var isCurrentlyActive: Bool {
        let now = Date()
        if let endTime = item.endTime {
            return now >= item.startTime && now <= endTime
        }
        // If no end time, consider active for 1 hour after start
        return now >= item.startTime && now <= item.startTime.addingTimeInterval(3600)
    }

    // Check if item has already passed (end time is before now)
    private var hasPassed: Bool {
        let now = Date()
        if let endTime = item.endTime {
            return endTime < now
        }
        // If no end time, check if start time is more than 1 hour ago
        return item.startTime.addingTimeInterval(3600) < now
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    private var timelineLineColor: Color {
        Color(hex: "9C9CA6").opacity(0.2)
    }

    // Time color - purple when active, gray otherwise
    private var timeColor: Color {
        isCurrentlyActive ? Color(hex: "8251EB") : Color(hex: "9E9EAA")
    }

    // Title color - dark for active and upcoming, gray only for passed items
    private var titleColor: Color {
        if hasPassed {
            return Color(hex: "9E9EAA") // Gray for passed items
        }
        return colorScheme == .dark ? Color.white : Color(hex: "0D1017") // Dark for active and upcoming
    }

    // Dot colors - gray for passed items, purple for upcoming
    private var dotOuterColor: Color {
        hasPassed ? Color(hex: "9C9CA6").opacity(0.3) : Color(hex: "E1D3FF")
    }

    private var dotInnerColor: Color {
        hasPassed ? Color(hex: "9C9CA6").opacity(0.5) : Color(hex: "A17BF4")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 4) {
                // Dot - gray for passed, purple for upcoming
                Circle()
                    .fill(dotOuterColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(dotInnerColor)
                            .frame(width: 12, height: 12)
                    )

                // Connecting line (not shown for last item)
                if !isLast {
                    Rectangle()
                        .fill(timelineLineColor)
                        .frame(width: 4)
                        .cornerRadius(2)
                }
            }
            .frame(width: 24)

            // Content card - white background, purple border when active
            VStack(alignment: .leading, spacing: 4) {
                // Time range
                Text(formatTimeRange())
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.44)
                    .foregroundColor(timeColor)

                // Title
                Text(item.title)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.44)
                    .foregroundColor(titleColor)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "A17BF4"), lineWidth: isCurrentlyActive ? 1 : 0)
            )

            // Selection indicator
            if isMultiSelectEnabled {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .rdPrimary : .rdTextSecondary)
                    .font(.system(size: 24))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLongPress()
                }
        )
        .onTapGesture(perform: onTapped)
    }

    private func formatTimeRange() -> String {
        let formatter = DateFormatter()

        if let endTime = item.endTime {
            // Check if both times are in the same AM/PM period
            let calendar = Calendar.current
            let startHour = calendar.component(.hour, from: item.startTime)
            let endHour = calendar.component(.hour, from: endTime)
            let startIsAM = startHour < 12
            let endIsAM = endHour < 12

            if startIsAM == endIsAM {
                // Same period - show AM/PM only at the end
                formatter.dateFormat = "h:mm"
                let start = formatter.string(from: item.startTime)
                formatter.dateFormat = "h:mm a"
                let end = formatter.string(from: endTime)
                return "\(start) - \(end)"
            } else {
                // Different periods - show both AM/PM
                formatter.dateFormat = "h:mm a"
                let start = formatter.string(from: item.startTime)
                let end = formatter.string(from: endTime)
                return "\(start) - \(end)"
            }
        }

        // No end time - just show start time with AM/PM
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: item.startTime)
    }
}

// MARK: - Agenda Empty View
/// Design reference: Figma node 301:35341 "Agenda Empty"
struct AgendaEmptyView: View {
    let onAddItem: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Illustration from Figma SVG asset (165x163.28 from Figma)
            Image("agenda_empty_illustration")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 165, height: 163)
                .padding(.bottom, 22) // Figma: pb-[22.122px]

            // Text content matching Figma exactly
            // Figma: width="361" height="40"
            VStack(spacing: 0) {
                Text("Build Your Event Timeline")
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.23) // Figma letter-spacing
                    .foregroundColor(.rdTextSecondary) // #83828d

                Text("Add sessions or activities to plan your day")
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.23) // Figma letter-spacing
                    .foregroundColor(.rdTextTertiary) // #9e9eaa
            }
            .lineSpacing(0)
            .multilineTextAlignment(.center)

            // Add Activity Button matching Figma
            // Figma: Button container pb-[16px] pt-[8px] px-[16px], button 313x48
            RDGradientButton("+ Add Activity", action: onAddItem)
                .padding(.horizontal, 16) // Figma: px-[16px]
                .padding(.top, 8) // Figma: pt-[8px]
                .padding(.bottom, 16) // Figma: pb-[16px]

            Spacer()
        }
        .padding(.horizontal, 24) // Figma: px-[24px]
        .padding(.top, 24) // Figma: pt-[24px]
        .padding(.bottom, 36) // Figma: pb-[36px]
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Agenda Delete Bar
struct AgendaDeleteBar: View {
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

// MARK: - Add Agenda Item Sheet
/// Design reference: Figma node 301:35600 "New Activity"
struct AddAgendaItemSheet: View {
    let eventId: String
    let eventDate: Date
    let nextOrder: Int
    let existingItems: [AgendaItem]
    let onAdd: (AgendaItem) -> Void
    let onReplace: (String, AgendaItem) -> Void  // (conflictingItemId, newItem)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title = ""
    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var selectedDuration: Int? = 15 // Default 15 minutes to match Figma
    @State private var showDatePicker = false
    @State private var showDurationPicker = false
    @FocusState private var isTitleFocused: Bool

    // Time conflict state
    @State private var showTimeConflict = false
    @State private var conflictingItem: AgendaItem?

    private let durationPresets = [15, 30, 45, 60] // minutes

    init(eventId: String, eventDate: Date, nextOrder: Int, existingItems: [AgendaItem], onAdd: @escaping (AgendaItem) -> Void, onReplace: @escaping (String, AgendaItem) -> Void) {
        self.eventId = eventId
        self.eventDate = eventDate
        self.nextOrder = nextOrder
        self.existingItems = existingItems
        self.onAdd = onAdd
        self.onReplace = onReplace

        // Default to event date and current time (rounded to nearest 15 min)
        _selectedDate = State(initialValue: eventDate)
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let roundedMinute = (minute / 15) * 15 // Round down to nearest 15
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        components.minute = roundedMinute
        components.second = 0
        let defaultStart = calendar.date(from: components) ?? now
        _startTime = State(initialValue: defaultStart)
    }

    private var endTime: Date {
        let duration = selectedDuration ?? 30
        return startTime.addingTimeInterval(TimeInterval(duration * 60))
    }

    private var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    // Check if new activity conflicts with existing ones
    private func findConflictingItem() -> AgendaItem? {
        let newStart = combineDateAndTime(date: selectedDate, time: startTime)
        let newEnd = combineDateAndTime(date: selectedDate, time: endTime)

        for item in existingItems {
            guard let itemEnd = item.endTime else { continue }

            // Check if times overlap
            // Overlap occurs if: newStart < itemEnd AND newEnd > itemStart
            if newStart < itemEnd && newEnd > item.startTime {
                return item
            }
        }
        return nil
    }

    // Format time range for conflict message
    private func formatConflictTimeRange(item: AgendaItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeStyle = .short
        let start = formatter.string(from: item.startTime)
        if let end = item.endTime {
            return "\(start)-\(formatter.string(from: end))"
        }
        return start
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveActivity() {
        // Check for time conflict first
        if let conflict = findConflictingItem() {
            conflictingItem = conflict
            showTimeConflict = true
        } else {
            // No conflict, add normally
            let item = AgendaItem(
                eventId: eventId,
                title: title,
                description: nil,
                startTime: combineDateAndTime(date: selectedDate, time: startTime),
                endTime: combineDateAndTime(date: selectedDate, time: endTime),
                location: nil,
                order: nextOrder
            )
            onAdd(item)
            dismiss()
        }
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
            // Background - matches Figma system grouped background
            (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7"))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with glass effect
                RDSheetHeader(
                    title: "New Activity",
                    canSave: canSave,
                    onDismiss: { dismiss() },
                    onSave: { saveActivity() }
                )

                ScrollView {
                    VStack(spacing: 0) {
                        // Title Section
                        titleSection

                        // Date Section
                        dateSection

                        // Time Section
                        timeSection

                        // Duration Section
                        durationSection
                    }
                    .padding(.bottom, 24) // Bottom padding for scroll content
                }
            }

            overlaysContent
        }
        .sheet(isPresented: $showDurationPicker) {
            MoreDurationPickerSheet(selectedDuration: $selectedDuration)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
    }

    private var legacyContent: some View {
        NavigationStack {
            ZStack {
                // Background - matches Figma system grouped background
                (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7"))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Title Section
                            titleSection

                            // Date Section
                            dateSection

                            // Time Section
                            timeSection

                            // Duration Section
                            durationSection
                        }
                        .padding(.bottom, 24) // Bottom padding for scroll content
                    }

                    // Add Button (only for pre-iOS 26)
                    addButton
                }

                overlaysContent
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showDurationPicker) {
            MoreDurationPickerSheet(selectedDuration: $selectedDuration)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var overlaysContent: some View {
        // Calendar picker overlay - same style as AI Event Planner
        if showDatePicker {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showDatePicker = false
                    }

                // Custom calendar picker - centered
                // Allow dates from today to event date (inclusive)
                CustomCalendarPicker(
                    selectedDate: $selectedDate,
                    minimumDate: nil,  // Today is already handled by CustomCalendarPicker
                    maximumDate: eventDate,  // Can't select dates after event
                    onDismiss: {
                        showDatePicker = false
                    }
                )
            }
        }

        // Time Conflict Alert
        if showTimeConflict, let conflict = conflictingItem {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showTimeConflict = false
                    }

                // Alert
                TimeConflictAlert(
                    conflictingActivityName: conflict.title,
                    conflictingTimeRange: formatConflictTimeRange(item: conflict),
                    onReplace: {
                        // Create new item and replace
                        let newItem = AgendaItem(
                            eventId: eventId,
                            title: title,
                            description: nil,
                            startTime: combineDateAndTime(date: selectedDate, time: startTime),
                            endTime: combineDateAndTime(date: selectedDate, time: endTime),
                            location: nil,
                            order: conflict.order  // Keep same order as replaced item
                        )
                        onReplace(conflict.id, newItem)
                        showTimeConflict = false
                        dismiss()
                    },
                    onCancel: {
                        showTimeConflict = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            .animation(.easeInOut(duration: 0.2), value: showTimeConflict)
        }
    }

    private func showDatePickerOverlay() {
        showDatePicker = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }


    // MARK: - Title Section
    /// Design reference: Figma node 301:35604
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header - Figma: h-[38px] with py-[4px] inside
            Text("TITLE")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color.black)
                .tracking(-0.13)
                .textCase(.uppercase)
                .frame(height: 30, alignment: .leading) // 38 - 8 (4px padding each side)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            // Input field - matches Figma 301:35615 (h-[52px], rounded-[12px])
            TextField("Name", text: $title)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.44)
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit {
                    isTitleFocused = false
                }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Date Section
    /// Design reference: Figma node 301:35621
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header - Figma: h-[38px] with py-[4px] inside
            Text("DATE")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "0D1017"))
                .tracking(-0.13)
                .textCase(.uppercase)
                .frame(height: 30, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            // Date field - matches Figma 301:35649 (h-[56px], gap-[12px], rounded-[12px])
            Button {
                showDatePickerOverlay()
            } label: {
                HStack(spacing: 12) {
                    // Reuse calendar_icon from AI Planner
                    Image("calendar_icon")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "8251EB"))

                    Text(formattedDate)
                        .font(.system(size: 17, weight: .regular))
                        .tracking(-0.43)
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 56)
                .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Time Section
    /// Design reference: Figma node 301:35657
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header - Figma: h-[38px] with py-[4px] inside
            Text("TIME")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color.black)
                .tracking(-0.13)
                .textCase(.uppercase)
                .frame(height: 30, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            // Time picker - p-[16px], rounded-[12px], height 158px content + 32px padding = 190px total
            TimeRangeWheelPicker(
                startTime: $startTime,
                duration: selectedDuration ?? 15
            )
            .id(selectedDuration) // Force re-render when duration changes
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Duration Section
    /// Design reference: Figma node 301:35669
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with "More +" link - Figma: h-[38px] with py-[4px] inside
            HStack {
                Text("DURATION")
                    .font(.system(size: 12, weight: .regular))
                    .tracking(-0.13)
                    .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color.black)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showDurationPicker = true
                } label: {
                    Text("More +")
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.44)
                        .foregroundColor(Color(hex: "8251EB"))
                        .padding(.leading, 20) // Figma: px-[20px] for right section
                }
            }
            .frame(height: 30)
            .padding(.vertical, 4)

            // iOS-style segmented control - p-[4px], rounded-[12px]
            DurationSegmentedControl(
                selectedDuration: $selectedDuration,
                options: durationPresets,
                colorScheme: colorScheme
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8) // Figma: py-[8px] for Input_Container
    }

    // MARK: - Add Button
    /// Design reference: Figma node 301:35701
    private var addButton: some View {
        VStack(spacing: 0) {
            RDGradientButton(
                "Add",
                isEnabled: !title.isEmpty
            ) {
                // Check for time conflict first
                if let conflict = findConflictingItem() {
                    conflictingItem = conflict
                    showTimeConflict = true
                } else {
                    // No conflict, add normally
                    let item = AgendaItem(
                        eventId: eventId,
                        title: title,
                        description: nil,
                        startTime: combineDateAndTime(date: selectedDate, time: startTime),
                        endTime: combineDateAndTime(date: selectedDate, time: endTime),
                        location: nil,
                        order: nextOrder
                    )
                    onAdd(item)
                    dismiss()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7"))
    }

    // MARK: - Helpers
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}

// MARK: - Time Range Wheel Picker
/// Design reference: Figma node 301:35667
/// Native UIPickerView wrapper for smooth scroll physics and haptics
/// Selected row shows range "8:00 - 8:15", unselected shows single time "8:15"
struct TimeRangeWheelPicker: View {
    @Binding var startTime: Date
    let duration: Int // in minutes

    @Environment(\.colorScheme) private var colorScheme

    // Dark mode adaptive colors
    private var containerBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    var body: some View {
        ZStack {
            // Native picker
            NativeTimePickerView(
                startTime: $startTime,
                duration: duration,
                isDarkMode: colorScheme == .dark
            )

            // Top gradient overlay
            VStack {
                LinearGradient(
                    colors: [containerBackground, containerBackground.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                Spacer()
            }
            .allowsHitTesting(false)

            // Bottom gradient overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [containerBackground.opacity(0), containerBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 158) // Figma: picker content height
        .padding(16) // Figma: p-[16px] all sides
        .background(containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Native UIPickerView Wrapper
struct NativeTimePickerView: UIViewRepresentable {
    @Binding var startTime: Date
    let duration: Int
    let isDarkMode: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        picker.backgroundColor = .clear

        // Set initial selection
        let initialRow = context.coordinator.indexForTime(startTime)
        picker.selectRow(initialRow, inComponent: 0, animated: false)

        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isDarkMode = isDarkMode

        // Update selection if startTime changed externally
        let currentRow = uiView.selectedRow(inComponent: 0)
        let expectedRow = context.coordinator.indexForTime(startTime)
        if currentRow != expectedRow {
            uiView.selectRow(expectedRow, inComponent: 0, animated: false)
        }

        // Reload to update colors for dark mode
        uiView.reloadAllComponents()
    }

    class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        var parent: NativeTimePickerView
        var isDarkMode: Bool
        private let timeSlots: [Date]
        private let formatter: DateFormatter
        private let selectionFeedback = UISelectionFeedbackGenerator()

        init(_ parent: NativeTimePickerView) {
            self.parent = parent
            self.isDarkMode = parent.isDarkMode

            // Generate time slots
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            self.timeSlots = (0..<96).compactMap { i in
                calendar.date(byAdding: .minute, value: i * 15, to: startOfDay)
            }

            self.formatter = DateFormatter()
            formatter.timeStyle = .short // Respects user's system time format (12h or 24h)

            super.init()
            selectionFeedback.prepare()
        }

        func indexForTime(_ time: Date) -> Int {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)
            return (hour * 4) + (minute / 15)
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            timeSlots.count
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            36
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let isSelected = pickerView.selectedRow(inComponent: 0) == row
            let slot = timeSlots[row]

            let label = (view as? UILabel) ?? UILabel()
            label.textAlignment = .center

            if isSelected {
                // Show time range for selected
                let endTime = slot.addingTimeInterval(TimeInterval(parent.duration * 60))
                label.text = "\(formatter.string(from: slot)) - \(formatter.string(from: endTime))"
                label.font = .systemFont(ofSize: 20, weight: .medium)
                label.textColor = isDarkMode ? .white : UIColor(hex: "0D1017")
            } else {
                // Show single time for unselected
                label.text = formatter.string(from: slot)
                label.font = .systemFont(ofSize: 20, weight: .regular)
                label.textColor = isDarkMode ? UIColor(hex: "8E8E93") : UIColor(hex: "9E9EAA")
            }

            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            selectionFeedback.selectionChanged()

            // Update the binding
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: parent.startTime)
            if let newTime = calendar.date(byAdding: .minute, value: row * 15, to: startOfDay) {
                parent.startTime = newTime
            }

            // Reload to update the visual state (selected vs unselected)
            pickerView.reloadAllComponents()
            pickerView.selectRow(row, inComponent: 0, animated: false)
        }
    }
}

// MARK: - UIColor hex extension for picker
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Duration Segmented Control
/// Design reference: Figma node 301:35688
struct DurationSegmentedControl: View {
    @Binding var selectedDuration: Int?
    let options: [Int] // minutes
    let colorScheme: ColorScheme

    private let selectionFeedback = UISelectionFeedbackGenerator()

    // Background is WHITE per Figma
    private var controlBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    // Selected segment background
    private var selectedBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color.white
    }

    // Text colors - Figma: #8251eb for selected, #0d1017 for unselected
    private var selectedTextColor: Color {
        Color(hex: "8251EB")
    }

    private var unselectedTextColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "0D1017")
    }

    private func displayText(for minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60) h"
        }
        return "\(minutes) m"
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, minutes in
                let isSelected = selectedDuration == minutes

                // Separator before item (except first, and not adjacent to selected)
                if index > 0 && selectedDuration != minutes && selectedDuration != options[index - 1] {
                    Rectangle()
                        .fill(Color(hex: "8E8E93").opacity(0.3))
                        .frame(width: 1, height: 12)
                }

                Button {
                    selectionFeedback.selectionChanged()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDuration = minutes
                    }
                } label: {
                    Text(displayText(for: minutes))
                        .font(.system(size: 17, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? selectedTextColor : unselectedTextColor)
                        .tracking(-0.44)
                        .lineSpacing(isSelected ? 20 - 17 : 24 - 17) // Figma: leading-[20px] selected, leading-[24px] unselected
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, isSelected ? 8 : 3) // Figma: py-[8px] selected, py-[3px] unselected
                        .background(
                            Group {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                                        )
                                        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 3)
                                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(controlBackground)
        )
        .onAppear {
            selectionFeedback.prepare()
        }
    }
}

// MARK: - Agenda Date Picker Sheet
struct AgendaDatePickerSheet: View {
    @Binding var selectedDate: Date
    let eventDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Date")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.rdTextPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.rdPrimary)
            }
            .padding(16)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.rdPrimary)
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.rdBackground)
    }
}

// MARK: - More Duration Picker Sheet
/// Design reference: Figma node 301:36015
struct MoreDurationPickerSheet: View {
    @Binding var selectedDuration: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var hours: Int = 0
    @State private var minutes: Int = 15

    // Preset chips that can be removed
    @State private var presets: [Int] = [15, 30, 45, 60]

    private let selectionFeedback = UISelectionFeedbackGenerator()

    // Dark mode adaptive colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white : .black
    }

    private var labelColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "16191C")
    }

    private var sectionTitleColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "0D1217")
    }

    private var closeButtonColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "3C3C43").opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Duration")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(titleColor)

                Spacer()

                Button {
                    // Apply selected duration and dismiss
                    selectedDuration = (hours * 60) + minutes
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(closeButtonColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)

            // iOS Timer Picker
            HStack(spacing: 45) {
                // Hours picker
                HStack(spacing: 4) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<13, id: \.self) { hour in
                            Text("\(hour)")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 50)
                    .clipped()

                    Text("hours")
                        .font(.system(size: 17))
                        .foregroundColor(labelColor)
                }

                // Minutes picker
                HStack(spacing: 3) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text("\(min)")
                                .tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 50)
                    .clipped()

                    Text("min")
                        .font(.system(size: 17))
                        .foregroundColor(labelColor)
                }
            }
            .frame(height: 180)
            .onChange(of: hours) { _, _ in
                selectionFeedback.selectionChanged()
            }
            .onChange(of: minutes) { _, _ in
                selectionFeedback.selectionChanged()
            }

            // Presets section
            VStack(alignment: .leading, spacing: 8) {
                Text("PRESETS")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(sectionTitleColor)
                    .tracking(-0.13)

                // Preset chips
                AgendaFlowLayout(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        PresetChip(
                            text: preset >= 60 ? "\(preset / 60) hour" : "\(preset) min",
                            colorScheme: colorScheme,
                            onRemove: {
                                selectionFeedback.selectionChanged()
                                withAnimation {
                                    presets.removeAll { $0 == preset }
                                }
                            },
                            onTap: {
                                selectionFeedback.selectionChanged()
                                // Set the picker values
                                hours = preset / 60
                                minutes = preset % 60
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onAppear {
            selectionFeedback.prepare()
            // Initialize from current selection
            if let duration = selectedDuration {
                hours = duration / 60
                minutes = duration % 60
            }
        }
    }
}

// MARK: - Preset Chip
struct PresetChip: View {
    let text: String
    let colorScheme: ColorScheme
    let onRemove: () -> Void
    let onTap: () -> Void

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "EDEDED")
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "1D192B")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(textColor)
                    .tracking(-0.08)

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(8)
        }
    }
}

// MARK: - Flow Layout for Preset Chips
struct AgendaFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Time Conflict Alert
/// Design reference: Figma node 301:35600 (rightmost screen)
struct TimeConflictAlert: View {
    let conflictingActivityName: String
    let conflictingTimeRange: String
    let onReplace: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Time Conflict")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.rdTextPrimary)
                .padding(.top, 20)
                .padding(.bottom, 12)

            // Description
            Text("This overlaps with \(conflictingTimeRange) '\(conflictingActivityName)'. Would you like to replace it with your new activity?")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.rdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            Divider()

            // Replace Activity button
            Button(action: onReplace) {
                Text("Replace Activity")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color.rdPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }

            Divider()

            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.rdTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .background(backgroundColor)
        .cornerRadius(14)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
    }
}

// MARK: - Time Conflict Overlay Modifier
extension View {
    func timeConflictAlert(
        isPresented: Binding<Bool>,
        conflictingActivityName: String,
        conflictingTimeRange: String,
        onReplace: @escaping () -> Void
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented.wrappedValue = false
                    }

                // Alert
                TimeConflictAlert(
                    conflictingActivityName: conflictingActivityName,
                    conflictingTimeRange: conflictingTimeRange,
                    onReplace: {
                        onReplace()
                        isPresented.wrappedValue = false
                    },
                    onCancel: {
                        isPresented.wrappedValue = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
    }
}

// MARK: - Delete Activities Alert
/// Design reference: Figma nodes 301:34866 (Delete Selected) and 301:34518 (Delete All)
struct DeleteActivitiesAlert: View {
    let title: String
    let message: String
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.rdTextPrimary)
                .padding(.top, 20)
                .padding(.bottom, 12)

            // Description
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.rdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            Divider()

            // Delete button
            Button(action: onDelete) {
                Text("Delete")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "DB4F47")) // warning/error color
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }

            Divider()

            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color.rdPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .background(backgroundColor)
        .cornerRadius(14)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
    }
}

// MARK: - View Model
@MainActor
class AgendaViewModel: ObservableObject {
    let eventId: String
    let eventDate: Date

    @Published var agendaItems: [AgendaItem] = []
    @Published var isLoading = true  // Start true to show shimmer on initial load
    @Published var isMultiSelectEnabled = false
    @Published var selectedItems: Set<String> = []
    @Published var isInitialized = false  // Tracks if data has been loaded at least once

    private let agendaRepository: AgendaRepositoryProtocol
    private let notificationRepository: NotificationRepositoryProtocol
    private let authService: AuthServiceProtocol
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    private var currentUserId: String? {
        authService.currentUser?.id
    }

    init(eventId: String, eventDate: Date, appState: AppState? = nil) {
        self.eventId = eventId
        self.eventDate = eventDate
        self.agendaRepository = DIContainer.shared.agendaRepository
        self.notificationRepository = DIContainer.shared.notificationRepository
        self.authService = DIContainer.shared.authService
        self.appState = appState

        // Load cached data from AppState immediately (no jumping)
        if let appState = appState {
            let cachedItems = appState.agendaItems(for: eventId)
            if !cachedItems.isEmpty {
                self.agendaItems = cachedItems
                self.isLoading = false
                self.isInitialized = true
            }
            subscribeToAppState(appState)
        }
    }

    /// Set AppState reference and subscribe to updates (called from View's onAppear)
    func setAppState(_ appState: AppState) {
        // Always check current cache state to determine loading
        let cachedItems = appState.agendaItems(for: eventId)
        if !cachedItems.isEmpty {
            self.agendaItems = cachedItems
            self.isLoading = false
            self.isInitialized = true
        } else {
            // No cache, ensure shimmer shows
            isLoading = true
        }

        // Only set up subscription once
        guard self.appState == nil else { return }
        self.appState = appState
        subscribeToAppState(appState)
    }

    private func subscribeToAppState(_ appState: AppState) {
        // Subscribe to AppState changes for real-time updates (push notifications)
        appState.$agendaByEvent
            .map { [eventId] in $0[eventId] ?? [] }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self = self else { return }
                // Only update if different to avoid loops
                if self.agendaItems != items {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.agendaItems = items
                    }
                    // Reset loading state when cache is cleared (to show shimmer)
                    // But NOT if already initialized (e.g. user deleted all items)
                    if items.isEmpty && !self.isInitialized {
                        self.isLoading = true
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadAgenda() async {
        // Use AppState to load (which handles caching)
        if let appState = appState {
            await appState.loadAgenda(for: eventId, eventDate: eventDate)
            // Sync local state with AppState cache BEFORE hiding shimmer
            let cachedItems = appState.agendaItems(for: eventId)
            if agendaItems != cachedItems {
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems = cachedItems
                }
            }
        } else {
            // Fallback: load directly without AppState
            do {
                let freshItems = try await agendaRepository.getAgendaForEvent(eventId: eventId)
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems = freshItems
                }
            } catch {
                // Load failed
            }
        }

        // Hide shimmer AFTER agendaItems is updated
        isLoading = false
        isInitialized = true
    }

    func toggleItemSelection(_ itemId: String) {
        if isMultiSelectEnabled {
            if selectedItems.contains(itemId) {
                selectedItems.remove(itemId)
            } else {
                selectedItems.insert(itemId)
            }
        }
    }

    /// Activate select mode via long-press and select the item
    func activateSelectMode(_ itemId: String) {
        isMultiSelectEnabled = true
        selectedItems.insert(itemId)
    }

    func addItem(_ item: AgendaItem) {
        // Optimistic update - add to UI immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems.append(item)
            appState?.addAgendaItem(item, eventId: eventId)
        }

        Task {
            do {
                let agendaId = try await agendaRepository.createAgendaItem(item)

                // Create the agenda item with the returned ID
                let createdItem = AgendaItem(
                    id: agendaId,
                    eventId: item.eventId,
                    title: item.title,
                    description: item.description,
                    startTime: item.startTime,
                    endTime: item.endTime,
                    location: item.location,
                    order: item.order
                )

                // Replace temp item with real one
                if let idx = agendaItems.firstIndex(where: { $0.id == item.id }) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        agendaItems[idx] = createdItem
                        appState?.updateAgendaItem(createdItem, eventId: eventId)
                    }
                }

                // Schedule notification for the agenda item
                if let userId = currentUserId {
                    await scheduleAgendaNotification(agenda: createdItem, userId: userId)
                }
            } catch {
                // Rollback on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems.removeAll { $0.id == item.id }
                    appState?.removeAgendaItem(id: item.id, eventId: eventId)
                }
            }
        }
    }

    func updateItem(_ item: AgendaItem) {
        guard let index = agendaItems.firstIndex(where: { $0.id == item.id }) else { return }
        let originalItem = agendaItems[index]

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems[index] = item
            appState?.updateAgendaItem(item, eventId: eventId)
        }

        Task {
            do {
                try await agendaRepository.updateAgendaItem(item)

                // Update notification for the agenda item
                if let userId = currentUserId {
                    // Delete old notification and create new one
                    await deleteAgendaNotification(agendaId: item.id)
                    await scheduleAgendaNotification(agenda: item, userId: userId)
                }
            } catch {
                // Rollback on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let idx = agendaItems.firstIndex(where: { $0.id == item.id }) {
                        agendaItems[idx] = originalItem
                        appState?.updateAgendaItem(originalItem, eventId: eventId)
                    }
                }
            }
        }
    }

    func replaceItem(conflictId: String, with newItem: AgendaItem) {
        guard let index = agendaItems.firstIndex(where: { $0.id == conflictId }) else { return }
        let originalItem = agendaItems[index]

        // Update the conflicting item with new values (instead of delete+create to avoid race condition)
        let updatedItem = AgendaItem(
            id: conflictId,  // Keep the same ID
            eventId: newItem.eventId,
            title: newItem.title,
            description: newItem.description,
            startTime: newItem.startTime,
            endTime: newItem.endTime,
            location: newItem.location,
            order: newItem.order
        )

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems[index] = updatedItem
            appState?.updateAgendaItem(updatedItem, eventId: eventId)
        }

        Task {
            do {
                try await agendaRepository.updateAgendaItem(updatedItem)

                // Update notification
                if let userId = currentUserId {
                    await deleteAgendaNotification(agendaId: conflictId)
                    await scheduleAgendaNotification(agenda: updatedItem, userId: userId)
                }
            } catch {
                // Rollback on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let idx = agendaItems.firstIndex(where: { $0.id == conflictId }) {
                        agendaItems[idx] = originalItem
                        appState?.updateAgendaItem(originalItem, eventId: eventId)
                    }
                }
            }
        }
    }

    func deleteItem(_ itemId: String) {
        guard let index = agendaItems.firstIndex(where: { $0.id == itemId }) else { return }
        let deletedItem = agendaItems[index]

        // Optimistic delete
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems.remove(at: index)
            appState?.removeAgendaItem(id: itemId, eventId: eventId)
        }

        Task {
            do {
                // Delete notification first
                await deleteAgendaNotification(agendaId: itemId)

                try await agendaRepository.deleteAgendaItem(id: itemId)
            } catch {
                // Rollback on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems.insert(deletedItem, at: min(index, agendaItems.count))
                    appState?.addAgendaItem(deletedItem, eventId: eventId)
                }
            }
        }
    }

    func deleteSelectedItems() {
        let idsToDelete = selectedItems
        let itemsToDelete = agendaItems.filter { idsToDelete.contains($0.id) }

        // Optimistic delete
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems.removeAll { idsToDelete.contains($0.id) }
            appState?.removeAgendaItems(ids: idsToDelete, eventId: eventId)
        }
        selectedItems.removeAll()
        isMultiSelectEnabled = false

        Task {
            var failedItems: [AgendaItem] = []
            for itemId in idsToDelete {
                do {
                    // Delete notification first
                    await deleteAgendaNotification(agendaId: itemId)

                    try await agendaRepository.deleteAgendaItem(id: itemId)
                } catch {
                    if let item = itemsToDelete.first(where: { $0.id == itemId }) {
                        failedItems.append(item)
                    }
                }
            }
            // Restore failed deletions
            if !failedItems.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems.append(contentsOf: failedItems)
                    for item in failedItems {
                        appState?.addAgendaItem(item, eventId: eventId)
                    }
                }
            }
        }
    }

    func deleteAllItems() {
        let itemsToDelete = agendaItems

        // Optimistic delete
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems.removeAll()
            appState?.removeAgendaItems(ids: Set(itemsToDelete.map(\.id)), eventId: eventId)
        }
        selectedItems.removeAll()
        isMultiSelectEnabled = false

        Task {
            var failedItems: [AgendaItem] = []
            for item in itemsToDelete {
                do {
                    // Delete notification first
                    await deleteAgendaNotification(agendaId: item.id)

                    try await agendaRepository.deleteAgendaItem(id: item.id)
                } catch {
                    failedItems.append(item)
                }
            }
            // Restore failed deletions
            if !failedItems.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    agendaItems.append(contentsOf: failedItems)
                    for item in failedItems {
                        appState?.addAgendaItem(item, eventId: eventId)
                    }
                }
            }
        }
    }

    func reorderItems(_ orderedIds: [String]) {
        // Reorder local items
        var reorderedItems: [AgendaItem] = []
        for id in orderedIds {
            if let item = agendaItems.first(where: { $0.id == id }) {
                reorderedItems.append(item)
            }
        }
        // Add any items not in the ordered list (shouldn't happen but just in case)
        for item in agendaItems {
            if !orderedIds.contains(item.id) {
                reorderedItems.append(item)
            }
        }

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            agendaItems = reorderedItems
            appState?.agendaByEvent[eventId] = reorderedItems
        }

        Task {
            do {
                try await agendaRepository.reorderAgenda(eventId: eventId, itemIds: orderedIds)
            } catch {
                // On failure, reload to get correct order from backend
                await loadAgenda()
            }
        }
    }

    // MARK: - Notification Methods

    private func scheduleAgendaNotification(agenda: AgendaItem, userId: String) async {
        do {
            guard let token = try await notificationRepository.getFcmToken() else {
                return
            }

            // Use a default notification period (15 minutes before)
            let period: AgendaReminderPeriod = .fifteenMinutesBefore

            if let request = AgendaNotificationHelper.buildCreateRequest(
                agenda: agenda,
                tokens: [token],
                userId: userId,
                eventId: eventId,
                period: period
            ) {
                _ = try await notificationRepository.createNotification(request)
            }
        } catch {
            // Error handled silently
        }
    }

    private func deleteAgendaNotification(agendaId: String) async {
        do {
            _ = try await notificationRepository.deleteNotificationsByGroup(groupField: .agendaId, groupValue: agendaId)
        } catch {
            // Error handled silently
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AgendaListView(eventId: "preview-event-id", eventDate: Date())
    }
}