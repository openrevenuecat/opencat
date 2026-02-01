import SwiftUI

struct EditEventView: View {
    @StateObject private var viewModel: EditEventViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDatePicker = false
    @State private var showDeleteConfirmation = false
    @State private var showDiscardAlert = false

    // Calendar picker state (at parent level for full-screen overlay)
    @State private var showCalendarPicker = false
    @State private var calendarPickerDate = Date()
    @State private var calendarPickerMinDate: Date? = nil
    @State private var calendarPickerOnSelect: ((Date) -> Void)? = nil

    // Time picker state (at parent level for full-screen overlay)
    @State private var showTimePicker = false
    @State private var timePickerDate = Date()
    @State private var timePickerOnSelect: ((Date) -> Void)? = nil

    /// Callback when the event is successfully updated
    var onEventUpdated: ((Event) -> Void)?
    /// Callback when the event is deleted
    var onEventDeleted: (() -> Void)?

    init(event: Event, onEventUpdated: ((Event) -> Void)? = nil, onEventDeleted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditEventViewModel(event: event))
        self.onEventUpdated = onEventUpdated
        self.onEventDeleted = onEventDeleted
    }

    var body: some View {
        ZStack {
            // Main content
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Large Title
                        LargeTitleHeader(title: L10n.editEvent)

                        VStack(spacing: 8) {
                            // Event Name Section
                            EditEventSection(title: "Event Name") {
                                EventNameTextField(text: $viewModel.eventName)
                            }

                            // Date & Time Section
                            EditEventSection(title: "Date and Time") {
                                DateTimeButton(
                                    formattedDate: viewModel.formattedDateRange,
                                    hasDate: true,
                                    action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            showDatePicker = true
                                        }
                                    }
                                )
                            }

                            // Venue Section
                            EditEventSection(title: "Venue") {
                                VenueTextField(text: $viewModel.venue)
                            }

                            // Custom Idea Section
                            EditEventSection(title: "Custom Idea") {
                                CustomIdeaTextField(text: $viewModel.customIdea)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }
                }
                .scrollBounceHaptic()
                .background(Color.rdBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BackButton {
                            handleBackAction()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        DoneButton(
                            isEnabled: viewModel.canSave,
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                await saveAndDismiss()
                            }
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
            }

            // Date Picker Overlay
            if showDatePicker {
                datePickerOverlay
            }

            // Calendar Picker Overlay - on top of everything (like AIEventPlannerView)
            if showCalendarPicker {
                calendarPickerOverlay
            }

            // Time Picker Overlay - on top of everything
            if showTimePicker {
                timePickerOverlay
            }
        }
        .animation(.spring(response: 0.3), value: showDatePicker)
        .animation(.easeInOut(duration: 0.2), value: showCalendarPicker)
        .animation(.easeInOut(duration: 0.2), value: showTimePicker)
        .alert(L10n.deleteEvent, isPresented: $showDeleteConfirmation) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                Task {
                    await deleteAndDismiss()
                }
            }
        } message: {
            Text(L10n.deleteEventConfirmation)
        }
        .alert(L10n.unsavedChanges, isPresented: $showDiscardAlert) {
            Button(L10n.discard, role: .destructive) {
                dismiss()
            }
            Button(L10n.save) {
                Task {
                    await saveAndDismiss()
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.unsavedChangesDesc)
        }
        .alert(L10n.error, isPresented: .constant(viewModel.error != nil)) {
            Button(L10n.ok) {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Date Picker Overlay

    private var datePickerOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showDatePicker = false
                    }
                }

            // Bottom sheet
            VStack {
                Spacer()

                EditEventDatePickerSheet(
                    selectedDate: $viewModel.startDate,
                    endDate: $viewModel.endDate,
                    isAllDay: $viewModel.isAllDay,
                    onShowCalendar: { date, minDate, onSelect in
                        calendarPickerDate = date
                        calendarPickerMinDate = minDate
                        calendarPickerOnSelect = onSelect
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarPicker = true
                        }
                    },
                    onShowTimePicker: { date, onSelect in
                        timePickerDate = date
                        timePickerOnSelect = onSelect
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTimePicker = true
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3)) {
                            showDatePicker = false
                        }
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - Calendar Picker Overlay

    private var calendarPickerOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCalendarPicker = false
                    }
                }

            // Custom calendar picker - centered
            CustomCalendarPicker(
                selectedDate: Binding(
                    get: { calendarPickerDate },
                    set: { newDate in
                        calendarPickerDate = newDate
                        // Call the callback immediately when date changes
                        calendarPickerOnSelect?(newDate)
                    }
                ),
                minimumDate: calendarPickerMinDate,
                maximumDate: nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCalendarPicker = false
                }
            }
        }
    }

    // MARK: - Time Picker Overlay

    @Environment(\.colorScheme) private var colorScheme

    private var timePickerOverlay: some View {
        ZStack {
            // Dimmed background - covers entire screen including status bar
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    timePickerOnSelect?(timePickerDate)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimePicker = false
                    }
                }

            // Time picker card - centered
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $timePickerDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 200)
            }
            .padding(16)
            .frame(width: 280)
            .background(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "F3F3F4"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.04), radius: 32, x: 0, y: 32)
            .shadow(color: Color.black.opacity(0.04), radius: 64, x: 0, y: 64)
        }
    }

    // MARK: - Private Methods
    private func handleBackAction() {
        if viewModel.hasChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func saveAndDismiss() async {
        if let updatedEvent = await viewModel.saveEventToRepository() {
            onEventUpdated?(updatedEvent)
            dismiss()
        }
    }

    private func deleteAndDismiss() async {
        if await viewModel.deleteEvent() {
            onEventDeleted?()
            dismiss()
        }
    }
}

// MARK: - Large Title Header
private struct LargeTitleHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.rdDisplay())
                .foregroundColor(.rdTextPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Edit Event Section
private struct EditEventSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with 38pt height (matches Figma)
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .regular))
                    .tracking(-0.13)
                    .foregroundColor(.rdTextSecondary)
                Spacer()
            }
            .frame(height: 38)

            content
        }
    }
}

// MARK: - Event Name TextField
private struct EventNameTextField: View {
    @Binding var text: String

    var body: some View {
        TextField("Name your event", text: $text)
            .font(.rdBody())
            .foregroundColor(.rdTextPrimary)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.rdBackgroundSecondary)
            .cornerRadius(12)
    }
}

// MARK: - Date Time Button
private struct DateTimeButton: View {
    let formattedDate: String
    let hasDate: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image("icon_calendar")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.rdPrimaryDark)
                    .frame(width: 24, height: 24)

                Text(formattedDate)
                    .font(.rdBody())
                    .foregroundColor(hasDate ? .rdTextPrimary : .rdTextTertiary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.rdBackgroundSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Venue TextField
private struct VenueTextField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image("icon_map_marker")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.rdPrimaryDark)
                .frame(width: 24, height: 24)

            TextField("Add venue", text: $text)
                .font(.rdBody())
                .foregroundColor(.rdTextPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.rdBackgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Custom Idea TextField
private struct CustomIdeaTextField: View {
    @Binding var text: String

    var body: some View {
        TextField("Add a custom idea or theme", text: $text)
            .font(.rdBody())
            .foregroundColor(.rdTextPrimary)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.rdBackgroundSecondary)
            .cornerRadius(12)
    }
}

// MARK: - Delete Event Button
private struct DeleteEventButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("icon_swipe_bin")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text(L10n.deleteEvent)
                    .font(.rdBody())

                Spacer()
            }
            .foregroundColor(.rdError)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.rdError.opacity(0.1))
            .cornerRadius(16)
        }
        .padding(.top, 16)
    }
}

// MARK: - Back Button
private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.rdTextPrimary)
        }
    }
}

// MARK: - Done Button
private struct DoneButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.rdAccent)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isEnabled ? .rdAccent : .rdTextTertiary)
            }
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Date Picker Sheet (AIEventPlanner Style)
struct EditEventDatePickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDate: Date
    @Binding var endDate: Date?
    @Binding var isAllDay: Bool

    // Callback to show calendar at parent level (for full-screen centering)
    var onShowCalendar: ((_ date: Date, _ minDate: Date?, _ onSelect: @escaping (Date) -> Void) -> Void)?
    // Callback to show time picker at parent level
    var onShowTimePicker: ((_ date: Date, _ onSelect: @escaping (Date) -> Void) -> Void)?
    // Callback to dismiss (since we're now an overlay, not a sheet)
    var onDismiss: (() -> Void)?

    // Local state for editing
    @State private var tempStartDate: Date
    @State private var tempEndDate: Date?
    @State private var tempIsAllDay: Bool

    init(
        selectedDate: Binding<Date>,
        endDate: Binding<Date?>,
        isAllDay: Binding<Bool>,
        onShowCalendar: ((_ date: Date, _ minDate: Date?, _ onSelect: @escaping (Date) -> Void) -> Void)? = nil,
        onShowTimePicker: ((_ date: Date, _ onSelect: @escaping (Date) -> Void) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        _selectedDate = selectedDate
        _endDate = endDate
        _isAllDay = isAllDay
        self.onShowCalendar = onShowCalendar
        self.onShowTimePicker = onShowTimePicker
        self.onDismiss = onDismiss
        _tempStartDate = State(initialValue: selectedDate.wrappedValue)
        _tempEndDate = State(initialValue: endDate.wrappedValue)
        _tempIsAllDay = State(initialValue: isAllDay.wrappedValue)
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Header with X close button only
            HStack {
                // Empty spacer to balance layout
                Color.clear.frame(width: 30, height: 30)

                Spacer()

                Text(L10n.dateAndTime)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(textPrimary)

                Spacer()

                // X close button
                RDCloseButton {
                    selectedDate = tempStartDate
                    endDate = tempEndDate
                    isAllDay = tempIsAllDay
                    onDismiss?()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Main card with rows
            VStack(spacing: 0) {
                // All Day Row
                HStack {
                    Text("All day")
                        .font(.system(size: 17))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Toggle("", isOn: $tempIsAllDay)
                        .tint(Color(hex: "A17BF4"))
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)

                sheetDivider

                // Starts Row
                HStack {
                    Text("Starts")
                        .font(.system(size: 17))
                        .foregroundColor(textPrimary)

                    Spacer()

                    HStack(spacing: 6) {
                        dateChipButton(date: tempStartDate, field: .startDate)

                        if !tempIsAllDay {
                            timeChipButton(field: .startDate)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)

                // Ends Row (if end date exists)
                if tempEndDate != nil {
                    sheetDivider

                    HStack {
                        Text("Ends")
                            .font(.system(size: 17))
                            .foregroundColor(textPrimary)

                        Spacer()

                        if let end = tempEndDate {
                            HStack(spacing: 6) {
                                dateChipButton(date: end, field: .endDate)

                                if !tempIsAllDay {
                                    timeChipButton(field: .endDate)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                }

                sheetDivider

                // Add/Remove End Time
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if tempEndDate == nil {
                            if tempIsAllDay {
                                tempEndDate = Calendar.current.date(byAdding: .day, value: 1, to: tempStartDate)
                            } else {
                                tempEndDate = tempStartDate.addingTimeInterval(3600)
                            }
                        } else {
                            tempEndDate = nil
                        }
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack {
                        Text(tempEndDate == nil ? "Add End Time" : "Remove End Time")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "8251EB"))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                }
            }
            .background(cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Confirm button with gradient
            RDGradientButton("Confirm") {
                selectedDate = tempStartDate
                endDate = tempEndDate
                isAllDay = tempIsAllDay
                onDismiss?()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var sheetDivider: some View {
        Divider()
            .background(Color(hex: "545456").opacity(0.34))
            .padding(.leading, 16)
    }

    private enum DateField {
        case startDate, endDate
    }

    // MARK: - Date Chip Button
    private func dateChipButton(date: Date, field: DateField) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Use callback to show calendar at parent level for full-screen centering
            let minDate: Date? = field == .endDate ? tempStartDate : nil
            onShowCalendar?(date, minDate) { selectedDate in
                if field == .startDate {
                    tempStartDate = selectedDate
                } else {
                    tempEndDate = selectedDate
                }
            }
        } label: {
            Text(formatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "787880").opacity(0.12))
                )
        }
    }

    // MARK: - Time Chip Button
    private func timeChipButton(field: DateField) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let currentDate = field == .startDate ? tempStartDate : (tempEndDate ?? tempStartDate.addingTimeInterval(3600))

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Use callback to show time picker at parent level
            onShowTimePicker?(currentDate) { selectedTime in
                // Extract just the time components from selectedTime
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)

                if field == .startDate {
                    // Combine current date with new time
                    var newComponents = calendar.dateComponents([.year, .month, .day], from: tempStartDate)
                    newComponents.hour = timeComponents.hour
                    newComponents.minute = timeComponents.minute
                    if let newDate = calendar.date(from: newComponents) {
                        tempStartDate = newDate
                    }
                } else {
                    // For end date
                    let baseDate = tempEndDate ?? tempStartDate.addingTimeInterval(3600)
                    var newComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
                    newComponents.hour = timeComponents.hour
                    newComponents.minute = timeComponents.minute
                    if let newDate = calendar.date(from: newComponents) {
                        tempEndDate = newDate
                    }
                }
            }
        } label: {
            Text(formatter.string(from: currentDate))
                .font(.system(size: 17))
                .foregroundColor(textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "787880").opacity(0.12))
                )
        }
    }
}

// MARK: - Preview
#Preview {
    EditEventView(event: Event.preview)
}

#Preview("Date Picker Sheet") {
    EditEventDatePickerSheet(
        selectedDate: .constant(Date()),
        endDate: .constant(nil),
        isAllDay: .constant(false),
        onShowCalendar: { _, _, _ in },
        onShowTimePicker: { _, _ in },
        onDismiss: {}
    )
}
