import SwiftUI

// MARK: - Event Details Step View

struct EventDetailsStepView: View {
    @Binding var eventName: String
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var venue: String

    let eventTypeName: String? // Pre-filled from step 1 selection
    let onContinue: () -> Void
    let onBack: () -> Void

    // Access shared ViewModel for calendar picker overlay (shown at parent level)
    @ObservedObject private var viewModel = AIEventPlannerViewModel.shared

    @State private var showDateTimeSheet = false
    @State private var hasSelectedDate = false
    @State private var tempStartDate = Date()
    @State private var tempEndDate: Date?

    // Track which field is being edited for calendar/time picker
    @State private var editingDateField: DateField?

    enum DateField {
        case startDate, startTime, endDate, endTime
    }

    @FocusState private var isEventNameFocused: Bool
    @FocusState private var isVenueFocused: Bool
    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dark Mode Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var textPlaceholderColor: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "99A1AF")
    }

    private var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var fieldBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var disabledButtonColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "D1D5DC")
    }

    private var canProceed: Bool {
        !eventName.trimmingCharacters(in: .whitespaces).isEmpty && hasSelectedDate
    }

    private var dateDisplayText: String {
        guard hasSelectedDate else {
            return "Select Date and Time"
        }

        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "MMM d"
        timeFormatter.dateFormat = "h:mm a"

        if viewModel.eventIsAllDay {
            let dateStr = dateFormatter.string(from: tempStartDate)
            if let end = tempEndDate, !Calendar.current.isDate(tempStartDate, inSameDayAs: end) {
                return "\(dateStr) - \(dateFormatter.string(from: end))"
            } else {
                return dateStr
            }
        } else {
            let dateStr = dateFormatter.string(from: tempStartDate)
            let timeStr = timeFormatter.string(from: tempStartDate)
            if let end = tempEndDate {
                let endDateStr = dateFormatter.string(from: end)
                let endTimeStr = timeFormatter.string(from: end)
                if Calendar.current.isDate(tempStartDate, inSameDayAs: end) {
                    return "\(dateStr), \(timeStr) - \(endTimeStr)"
                } else {
                    return "\(dateStr), \(timeStr) - \(endDateStr), \(endTimeStr)"
                }
            } else {
                return "\(dateStr), \(timeStr)"
            }
        }
    }

    var body: some View {
        ZStack {
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Back button
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .regular))
                            Text("Back")
                                .font(.system(size: 16, weight: .regular))
                                .tracking(-0.31)
                        }
                        .foregroundColor(textSecondaryColor)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)

                    // AI Avatar - no animation, appears immediately
                    AIAvatarView(size: .small)

                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tell us about your event")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(textPrimaryColor)
                            .tracking(0.4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("Add event name, date, time and venue details")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.44)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                    // Form fields
                    VStack(spacing: 12) {
                        // Event Name field
                        eventNameField

                        // Date/Time picker button
                        datePickerButton

                        // Venue field
                        venueField

                        // Continue button
                        continueButton
                    }
                    .padding(.top, 24)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollBounceHaptic()
        }
        .overlay {
            if showDateTimeSheet {
                dateTimePickerOverlay
                    .transition(.identity)
                    .onAppear {
                        editingDateField = nil
                    }
            }
        }
        .onAppear {
            isVisible = true
            // Pre-fill event name with event type if empty
            if eventName.isEmpty, let typeName = eventTypeName {
                eventName = typeName
            }
            // Initialize tempStartDate from startDate if available
            if let existingStart = startDate {
                tempStartDate = existingStart
                hasSelectedDate = true
            }
            if let existingEnd = endDate {
                tempEndDate = existingEnd
            }
        }
        .onChange(of: hasSelectedDate) { _, newValue in
            if newValue {
                startDate = tempStartDate
                endDate = tempEndDate
            }
        }
    }

    // MARK: - Date Time Picker Overlay

    @State private var sheetOffset: CGFloat = 1000
    @State private var backgroundOpacity: Double = 0

    private var dateTimePickerOverlay: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSheet()
                }

            VStack {
                Spacer()
                dateTimeSheetContent
                    .offset(y: sheetOffset)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetOffset = 0
                backgroundOpacity = 0.4
            }
        }
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sheetOffset = 1000
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showDateTimeSheet = false
        }
    }

    // MARK: - Date Time Sheet Content

    private var dateTimeSheetContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Date and Time")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))
                    .tracking(-0.26)

                Spacer()

                RDCloseButton { dismissSheet() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Main card with rows
            VStack(spacing: 0) {
                // All Day Row
                HStack {
                    Text("All day")
                        .font(.system(size: 17))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))

                    Spacer()

                    Toggle("", isOn: $viewModel.eventIsAllDay)
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
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))

                    Spacer()

                    HStack(spacing: 6) {
                        dateChipButton(date: tempStartDate, field: .startDate)

                        if !viewModel.eventIsAllDay {
                            timeChipButton(date: tempStartDate, field: .startTime)
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
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))

                        Spacer()

                        if let end = tempEndDate {
                            HStack(spacing: 6) {
                                dateChipButton(date: end, field: .endDate)

                                if !viewModel.eventIsAllDay {
                                    timeChipButton(date: end, field: .endTime)
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
                            if viewModel.eventIsAllDay {
                                tempEndDate = Calendar.current.date(byAdding: .day, value: 2, to: tempStartDate)
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
            .background(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
                .frame(height: 24)

            // Confirm button
            Button {
                hasSelectedDate = true
                dismissSheet()
            } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8251EB"), Color(hex: "A78BFA"), Color(hex: "6366F1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 48)
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7"))
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
    }

    private var sheetHeight: CGFloat {
        // Header: ~44, Card: 132 (3 rows), Gap: 24, Button: 48, Top: 8, Bottom: 48
        let baseHeight: CGFloat = 44 + 132 + 24 + 48 + 8 + 48
        return baseHeight + (tempEndDate != nil ? 44 : 0)
    }

    private var sheetDivider: some View {
        Divider()
            .background(Color(hex: "545456").opacity(0.34))
            .padding(.leading, 16)
    }

    // MARK: - Date/Time Chip Buttons

    private func dateChipButton(date: Date, field: DateField) -> some View {
        let isSelected = editingDateField == field && viewModel.showCalendarPickerOverlay
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"

        return Button {
            editingDateField = field
            let minDate = field == .endDate ? tempStartDate : nil
            // Pass range dates for highlighting: when editing start, pass end as rangeEndDate
            // When editing end, pass start as rangeStartDate
            let rangeStart = field == .endDate ? tempStartDate : nil
            let rangeEnd = field == .startDate ? tempEndDate : nil
            viewModel.showCalendarPicker(
                date: date,
                minDate: minDate,
                rangeStartDate: rangeStart,
                rangeEndDate: rangeEnd
            ) { selectedDate in
                applyDateSelection(selectedDate: selectedDate, for: field)
                editingDateField = nil
            }
        } label: {
            Text(formatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? Color(hex: "8251EB") : (colorScheme == .dark ? .white : Color(hex: "0D1017")))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color(hex: "8251EB").opacity(0.15)
                        : (colorScheme == .dark ? Color(hex: "3A3A3C") : Color(red: 120/255, green: 120/255, blue: 128/255).opacity(0.12))
                )
                .cornerRadius(6)
        }
    }

    private func timeChipButton(date: Date, field: DateField) -> some View {
        let isSelected = editingDateField == field && viewModel.showTimePickerOverlay
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"

        return Button {
            editingDateField = field
            viewModel.showTimePicker(date: date) { selectedDate in
                applyTimeSelection(selectedDate: selectedDate, for: field)
                editingDateField = nil
            }
        } label: {
            Text(formatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? Color(hex: "8251EB") : (colorScheme == .dark ? .white : Color(hex: "0D1017")))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color(hex: "8251EB").opacity(0.15)
                        : (colorScheme == .dark ? Color(hex: "3A3A3C") : Color(red: 120/255, green: 120/255, blue: 128/255).opacity(0.12))
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Helper Methods (Date/Time Selection)

    private func applyDateSelection(selectedDate: Date, for field: DateField) {
        let calendar = Calendar.current

        switch field {
        case .startDate:
            let startComponents = calendar.dateComponents([.hour, .minute], from: tempStartDate)
            var newComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            newComponents.hour = startComponents.hour
            newComponents.minute = startComponents.minute
            if let newDate = calendar.date(from: newComponents) {
                tempStartDate = newDate
                if let end = tempEndDate, end < newDate {
                    tempEndDate = viewModel.eventIsAllDay
                        ? calendar.date(byAdding: .day, value: 2, to: newDate)
                        : newDate.addingTimeInterval(3600)
                }
            }

        case .endDate:
            if let end = tempEndDate {
                let endComponents = calendar.dateComponents([.hour, .minute], from: end)
                var newComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                newComponents.hour = endComponents.hour
                newComponents.minute = endComponents.minute
                if let newDate = calendar.date(from: newComponents) {
                    tempEndDate = newDate
                }
            }

        default:
            break
        }
    }

    private func applyTimeSelection(selectedDate: Date, for field: DateField) {
        let calendar = Calendar.current

        switch field {
        case .startTime:
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedDate)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: tempStartDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            if let newDate = calendar.date(from: dateComponents) {
                tempStartDate = newDate
                if let end = tempEndDate, end <= newDate {
                    tempEndDate = newDate.addingTimeInterval(3600)
                }
            }

        case .endTime:
            if tempEndDate != nil {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: tempEndDate!)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                if let newDate = calendar.date(from: dateComponents), newDate > tempStartDate {
                    tempEndDate = newDate
                }
            }

        default:
            break
        }
    }

    // MARK: - Event Name Field

    private var eventNameField: some View {
        TextField("Event Name", text: $eventName)
            .font(.system(size: 18, weight: .regular))
            .foregroundColor(textPrimaryColor)
            .tracking(-0.44)
            .focused($isEventNameFocused)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(height: 61)
            .background(fieldBackgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isEventNameFocused ? Color(hex: "8251EB") : fieldBorderColor,
                        lineWidth: 0.6
                    )
            )
    }

    // MARK: - Date Picker Button

    private var datePickerButton: some View {
        Button(action: {
            isEventNameFocused = false
            isVenueFocused = false
            sheetOffset = 1000
            backgroundOpacity = 0
            showDateTimeSheet = true
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            HStack(spacing: 12) {
                Image("calendar_icon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(hex: "8251EB"))

                Text(dateDisplayText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(hasSelectedDate ? textPrimaryColor : textPlaceholderColor)
                    .tracking(-0.44)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(height: 61)
            .background(fieldBackgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(fieldBorderColor, lineWidth: 0.6)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Venue Field

    private var venueField: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("location_icon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(Color(hex: "8251EB"))
                .padding(.top, 2)

            TextField("Venue (Optional)", text: $venue, axis: .vertical)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.44)
                .lineSpacing(7)
                .focused($isVenueFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 61)
        .background(fieldBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isVenueFocused ? Color(hex: "8251EB") : fieldBorderColor,
                    lineWidth: 0.6
                )
        )
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            if canProceed {
                onContinue()
            }
        }) {
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .tracking(-0.44)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    canProceed
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "8251EB"),
                                Color(hex: "A78BFA"),
                                Color(hex: "6366F1")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [disabledButtonColor]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(16)
        }
        .disabled(!canProceed)
    }
}

// MARK: - Preview

#Preview("Event Details Step - Empty") {
    struct PreviewWrapper: View {
        @State private var eventName = ""
        @State private var startDate: Date? = nil
        @State private var endDate: Date? = nil
        @State private var venue = ""

        var body: some View {
            EventDetailsStepView(
                eventName: $eventName,
                startDate: $startDate,
                endDate: $endDate,
                venue: $venue,
                eventTypeName: nil,
                onContinue: {},
                onBack: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}

#Preview("Event Details Step - With Event Type") {
    struct PreviewWrapper: View {
        @State private var eventName = "Birthday"
        @State private var startDate: Date? = Date()
        @State private var endDate: Date? = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        @State private var venue = ""

        var body: some View {
            EventDetailsStepView(
                eventName: $eventName,
                startDate: $startDate,
                endDate: $endDate,
                venue: $venue,
                eventTypeName: "Birthday",
                onContinue: {},
                onBack: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
