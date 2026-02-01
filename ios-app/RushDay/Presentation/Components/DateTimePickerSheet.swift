import SwiftUI

// MARK: - Date Time Picker Sheet Content (for overlay use)

struct DateTimePickerSheetContent: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var isAllDay: Bool
    @Binding var hasSelectedDate: Bool
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var showCalendarPicker = false
    @State private var showTimePicker = false
    @State private var editingField: EditingField?
    @State private var tempDate: Date = Date()

    private enum EditingField {
        case startDate
        case startTime
        case endDate
        case endTime
    }

    // MARK: - Theme Colors

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var chipBackgroundColor: Color {
        colorScheme == .dark
            ? Color(hex: "3A3A3C")
            : Color(red: 120/255, green: 120/255, blue: 128/255).opacity(0.12)
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "3C3C43").opacity(0.6)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "545456").opacity(0.34) : Color(hex: "545456").opacity(0.34)
    }

    private var purpleColor: Color {
        Color(hex: "8251EB")
    }

    private var toggleOnColor: Color {
        Color(hex: "A17BF4")
    }

    // MARK: - Date Formatters

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    // Dynamic height based on content
    private var dynamicHeight: CGFloat {
        let baseHeight: CGFloat = 280
        let endTimeRowHeight: CGFloat = endDate != nil ? 44 : 0
        return baseHeight + endTimeRowHeight
    }

    var body: some View {
        ZStack {
            // Main sheet content
            VStack(spacing: 0) {
                // Header
                headerView

                // Main card with rows
                mainCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                // Confirm button
                confirmButton
            }
            .frame(height: dynamicHeight)
            .background(backgroundColor)
            .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))

            // Calendar picker overlay
            if showCalendarPicker {
                calendarPickerOverlay
                    .transition(.opacity)
            }

            // Time picker overlay
            if showTimePicker {
                timePickerOverlay
                    .transition(.opacity)
            }
        }
        .frame(height: dynamicHeight)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Date and Time")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.26)

            Spacer()

            RDCloseButton { onDismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // All Day Row
            allDayRow

            Divider()
                .background(dividerColor)
                .padding(.leading, 16)

            // Starts Row
            startsRow

            // Ends Row (if end date exists)
            if endDate != nil {
                Divider()
                    .background(dividerColor)
                    .padding(.leading, 16)

                endsRow
            }

            Divider()
                .background(dividerColor)
                .padding(.leading, 16)

            // Add/Remove End Time
            addRemoveEndTimeRow
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }

    // MARK: - All Day Row

    private var allDayRow: some View {
        HStack {
            Text("All day")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            Toggle("", isOn: $isAllDay)
                .tint(toggleOnColor)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Starts Row

    private var startsRow: some View {
        HStack {
            Text("Starts")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            HStack(spacing: 6) {
                // Date chip
                dateChip(
                    date: startDate,
                    isSelected: editingField == .startDate && showCalendarPicker
                ) {
                    editingField = .startDate
                    tempDate = startDate
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = true
                        showTimePicker = false
                    }
                }

                // Time chip (only if not all day)
                if !isAllDay {
                    timeChip(
                        date: startDate,
                        isSelected: editingField == .startTime && showTimePicker
                    ) {
                        editingField = .startTime
                        tempDate = startDate
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showTimePicker = true
                            showCalendarPicker = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Ends Row

    private var endsRow: some View {
        HStack {
            Text("Ends")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            if let end = endDate {
                HStack(spacing: 6) {
                    // Date chip
                    dateChip(
                        date: end,
                        isSelected: editingField == .endDate && showCalendarPicker
                    ) {
                        editingField = .endDate
                        tempDate = end
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarPicker = true
                            showTimePicker = false
                        }
                    }

                    // Time chip (only if not all day)
                    if !isAllDay {
                        timeChip(
                            date: end,
                            isSelected: editingField == .endTime && showTimePicker
                        ) {
                            editingField = .endTime
                            tempDate = end
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimePicker = true
                                showCalendarPicker = false
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Add/Remove End Time Row

    private var addRemoveEndTimeRow: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if endDate == nil {
                    if isAllDay {
                        endDate = Calendar.current.date(byAdding: .day, value: 2, to: startDate)
                    } else {
                        endDate = startDate.addingTimeInterval(3600)
                    }
                } else {
                    endDate = nil
                }
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack {
                Text(endDate == nil ? "Add End Time" : "Remove End Time")
                    .font(.system(size: 17))
                    .foregroundColor(purpleColor)
                    .tracking(-0.43)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
    }

    // MARK: - Date Chip

    private func dateChip(date: Date, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(dateFormatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? purpleColor : textPrimaryColor)
                .tracking(-0.43)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? purpleColor.opacity(0.15)
                        : chipBackgroundColor
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Time Chip

    private func timeChip(date: Date, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(timeFormatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? purpleColor : textPrimaryColor)
                .tracking(-0.43)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? purpleColor.opacity(0.15)
                        : chipBackgroundColor
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        VStack(spacing: 0) {
            Button {
                hasSelectedDate = true
                onDismiss()
            } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "8251EB"),
                                Color(hex: "A78BFA"),
                                Color(hex: "6366F1")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // Computed property for range start date (DateTimePickerSheetContent)
    private var contentRangeStartDate: Date? {
        guard endDate != nil else { return nil }
        if case .endDate = editingField {
            return startDate
        }
        return nil
    }

    // Computed property for range end date (DateTimePickerSheetContent)
    private var contentRangeEndDate: Date? {
        guard let end = endDate else { return nil }
        if case .startDate = editingField {
            return end
        }
        return nil
    }

    // MARK: - Calendar Picker Overlay

    private var calendarPickerOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = false
                        editingField = nil
                    }
                }

            // Custom Calendar Picker with month dropdown and range highlighting
            CustomCalendarPicker(
                selectedDate: $tempDate,
                minimumDate: editingField == .endDate ? startDate : nil,
                rangeStartDate: contentRangeStartDate,
                rangeEndDate: contentRangeEndDate,
                onDismiss: {
                    applyDateSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = false
                        editingField = nil
                    }
                }
            )
            .id(editingField.map { "\($0)" } ?? "none")  // Force recreation when editing field changes
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: - Time Picker Overlay

    private var timePickerOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background - tap to dismiss
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        applyTimeSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showTimePicker = false
                            editingField = nil
                        }
                    }

                // Time picker floating card - positioned near the right side
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $tempDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(width: 160, height: 180)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(cardBackgroundColor)
                        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 3)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 6)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 12)
                        .shadow(color: Color.black.opacity(0.04), radius: 32, x: 0, y: 32)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color(hex: "EBECF0"), lineWidth: 1)
                )
                .position(
                    x: geometry.size.width - 120,
                    y: calculateTimePickerYPosition(for: editingField)
                )
            }
        }
    }

    // Calculate Y position for time picker based on which field is being edited
    private func calculateTimePickerYPosition(for field: EditingField?) -> CGFloat {
        let baseY: CGFloat = 100
        switch field {
        case .startTime:
            return baseY
        case .endTime:
            return baseY + 44
        default:
            return baseY
        }
    }

    // MARK: - Helper Methods

    private func applyDateSelection() {
        let calendar = Calendar.current

        switch editingField {
        case .startDate:
            let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
            var newComponents = calendar.dateComponents([.year, .month, .day], from: tempDate)
            newComponents.hour = startComponents.hour
            newComponents.minute = startComponents.minute
            if let newDate = calendar.date(from: newComponents) {
                startDate = newDate
                if let end = endDate, end < newDate {
                    if isAllDay {
                        endDate = calendar.date(byAdding: .day, value: 2, to: newDate)
                    } else {
                        endDate = newDate.addingTimeInterval(3600)
                    }
                }
            }

        case .endDate:
            if let end = endDate {
                let endComponents = calendar.dateComponents([.hour, .minute], from: end)
                var newComponents = calendar.dateComponents([.year, .month, .day], from: tempDate)
                newComponents.hour = endComponents.hour
                newComponents.minute = endComponents.minute
                if let newDate = calendar.date(from: newComponents) {
                    endDate = newDate
                }
            }

        default:
            break
        }
    }

    private func applyTimeSelection() {
        let calendar = Calendar.current

        switch editingField {
        case .startTime:
            let timeComponents = calendar.dateComponents([.hour, .minute], from: tempDate)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            if let newDate = calendar.date(from: dateComponents) {
                startDate = newDate
                if let end = endDate, end <= newDate {
                    endDate = newDate.addingTimeInterval(3600)
                }
            }

        case .endTime:
            if endDate != nil {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: tempDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: endDate!)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                if let newDate = calendar.date(from: dateComponents) {
                    if newDate > startDate {
                        endDate = newDate
                    }
                }
            }

        default:
            break
        }
    }
}

// MARK: - Rounded Corner Helper

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Date Time Picker Sheet (for .sheet() use - legacy)

struct DateTimePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var isAllDay: Bool
    @Binding var hasSelectedDate: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCalendarPicker = false
    @State private var showTimePicker = false
    @State private var editingField: EditingField?
    @State private var tempDate: Date = Date()

    private enum EditingField {
        case startDate
        case startTime
        case endDate
        case endTime
    }

    // MARK: - Theme Colors

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var chipBackgroundColor: Color {
        colorScheme == .dark
            ? Color(hex: "3A3A3C")
            : Color(red: 120/255, green: 120/255, blue: 128/255).opacity(0.12)
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "3C3C43").opacity(0.6)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(hex: "545456").opacity(0.34) : Color(hex: "545456").opacity(0.34)
    }

    private var purpleColor: Color {
        Color(hex: "8251EB")
    }

    private var toggleOnColor: Color {
        Color(hex: "A17BF4")
    }

    // MARK: - Date Formatters

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Header
                headerView

                // Main card with rows
                mainCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                // Confirm button
                confirmButton
            }
            .background(backgroundColor)

            // Calendar picker overlay
            if showCalendarPicker {
                calendarPickerOverlay
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Time picker overlay
            if showTimePicker {
                timePickerOverlay
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .presentationDetents([.height(dynamicHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    // Dynamic height based on content
    private var dynamicHeight: CGFloat {
        let baseHeight: CGFloat = 280
        let endTimeRowHeight: CGFloat = endDate != nil ? 44 : 0
        return baseHeight + endTimeRowHeight
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Date and Time")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.26)

            Spacer()

            RDCloseButton { dismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // All Day Row
            allDayRow

            Divider()
                .background(dividerColor)
                .padding(.leading, 16)

            // Starts Row
            startsRow

            // Ends Row (if end date exists)
            if endDate != nil {
                Divider()
                    .background(dividerColor)
                    .padding(.leading, 16)

                endsRow
            }

            Divider()
                .background(dividerColor)
                .padding(.leading, 16)

            // Add/Remove End Time
            addRemoveEndTimeRow
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }

    // MARK: - All Day Row

    private var allDayRow: some View {
        HStack {
            Text("All day")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            Toggle("", isOn: $isAllDay)
                .tint(toggleOnColor)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Starts Row

    private var startsRow: some View {
        HStack {
            Text("Starts")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            HStack(spacing: 6) {
                // Date chip
                dateChip(
                    date: startDate,
                    isSelected: editingField == .startDate && showCalendarPicker
                ) {
                    editingField = .startDate
                    tempDate = startDate
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = true
                        showTimePicker = false
                    }
                }

                // Time chip (only if not all day)
                if !isAllDay {
                    timeChip(
                        date: startDate,
                        isSelected: editingField == .startTime && showTimePicker
                    ) {
                        editingField = .startTime
                        tempDate = startDate
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showTimePicker = true
                            showCalendarPicker = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Ends Row

    private var endsRow: some View {
        HStack {
            Text("Ends")
                .font(.system(size: 17))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.43)

            Spacer()

            if let end = endDate {
                HStack(spacing: 6) {
                    // Date chip
                    dateChip(
                        date: end,
                        isSelected: editingField == .endDate && showCalendarPicker
                    ) {
                        editingField = .endDate
                        tempDate = end
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarPicker = true
                            showTimePicker = false
                        }
                    }

                    // Time chip (only if not all day)
                    if !isAllDay {
                        timeChip(
                            date: end,
                            isSelected: editingField == .endTime && showTimePicker
                        ) {
                            editingField = .endTime
                            tempDate = end
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimePicker = true
                                showCalendarPicker = false
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Add/Remove End Time Row

    private var addRemoveEndTimeRow: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if endDate == nil {
                    // Add end time - default to 2 days after start for all day, 1 hour for timed
                    if isAllDay {
                        endDate = Calendar.current.date(byAdding: .day, value: 2, to: startDate)
                    } else {
                        endDate = startDate.addingTimeInterval(3600)
                    }
                } else {
                    // Remove end time
                    endDate = nil
                }
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack {
                Text(endDate == nil ? "Add End Time" : "Remove End Time")
                    .font(.system(size: 17))
                    .foregroundColor(purpleColor)
                    .tracking(-0.43)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
    }

    // MARK: - Date Chip

    private func dateChip(date: Date, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(dateFormatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? purpleColor : textPrimaryColor)
                .tracking(-0.43)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? purpleColor.opacity(0.15)
                        : chipBackgroundColor
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Time Chip

    private func timeChip(date: Date, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(timeFormatter.string(from: date))
                .font(.system(size: 17))
                .foregroundColor(isSelected ? purpleColor : textPrimaryColor)
                .tracking(-0.43)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? purpleColor.opacity(0.15)
                        : chipBackgroundColor
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        VStack(spacing: 0) {
            Button {
                hasSelectedDate = true
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "8251EB"),
                                Color(hex: "A78BFA"),
                                Color(hex: "6366F1")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // Computed property for range start date (DateTimePickerSheet)
    private var sheetRangeStartDate: Date? {
        guard endDate != nil else { return nil }
        if case .endDate = editingField {
            return startDate
        }
        return nil
    }

    // Computed property for range end date (DateTimePickerSheet)
    private var sheetRangeEndDate: Date? {
        guard let end = endDate else { return nil }
        if case .startDate = editingField {
            return end
        }
        return nil
    }

    // MARK: - Calendar Picker Overlay

    private var calendarPickerOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = false
                        editingField = nil
                    }
                }

            // Custom Calendar Picker with month dropdown and range highlighting
            CustomCalendarPicker(
                selectedDate: $tempDate,
                minimumDate: editingField == .endDate ? startDate : nil,
                rangeStartDate: sheetRangeStartDate,
                rangeEndDate: sheetRangeEndDate,
                onDismiss: {
                    applyDateSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showCalendarPicker = false
                        editingField = nil
                    }
                }
            )
            .id(editingField.map { "\($0)" } ?? "none")  // Force recreation when editing field changes
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: - Time Picker Overlay

    private var timePickerOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background - tap to dismiss
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        applyTimeSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showTimePicker = false
                            editingField = nil
                        }
                    }

                // Time picker floating card - positioned near the right side
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $tempDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(width: 160, height: 180)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(cardBackgroundColor)
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 1,
                            x: 0,
                            y: 1
                        )
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 3,
                            x: 0,
                            y: 3
                        )
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 6,
                            x: 0,
                            y: 6
                        )
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 12,
                            x: 0,
                            y: 12
                        )
                        .shadow(
                            color: Color.black.opacity(0.04),
                            radius: 32,
                            x: 0,
                            y: 32
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color(hex: "EBECF0"), lineWidth: 1)
                )
                .position(
                    x: geometry.size.width - 120,
                    y: calculateTimePickerYPosition(for: editingField, in: geometry)
                )
            }
        }
    }

    // Calculate Y position for time picker based on which field is being edited
    private func calculateTimePickerYPosition(for field: EditingField?, in geometry: GeometryProxy) -> CGFloat {
        // Base position - near the Starts row
        let baseY: CGFloat = 160

        switch field {
        case .startTime:
            return baseY
        case .endTime:
            return baseY + 44 // Move down for Ends row
        default:
            return baseY
        }
    }

    private func applyDateSelection() {
        let calendar = Calendar.current

        switch editingField {
        case .startDate:
            // Keep the time from startDate, but change the date
            let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
            var newComponents = calendar.dateComponents([.year, .month, .day], from: tempDate)
            newComponents.hour = startComponents.hour
            newComponents.minute = startComponents.minute
            if let newDate = calendar.date(from: newComponents) {
                startDate = newDate
                // If end date exists and is before new start, adjust it
                if let end = endDate, end < newDate {
                    if isAllDay {
                        endDate = calendar.date(byAdding: .day, value: 2, to: newDate)
                    } else {
                        endDate = newDate.addingTimeInterval(3600)
                    }
                }
            }

        case .endDate:
            // Keep the time from endDate, but change the date
            if let end = endDate {
                let endComponents = calendar.dateComponents([.hour, .minute], from: end)
                var newComponents = calendar.dateComponents([.year, .month, .day], from: tempDate)
                newComponents.hour = endComponents.hour
                newComponents.minute = endComponents.minute
                if let newDate = calendar.date(from: newComponents) {
                    endDate = newDate
                }
            }

        default:
            break
        }
    }

    private func applyTimeSelection() {
        let calendar = Calendar.current

        switch editingField {
        case .startTime:
            // Keep the date from startDate, but change the time
            let timeComponents = calendar.dateComponents([.hour, .minute], from: tempDate)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            if let newDate = calendar.date(from: dateComponents) {
                startDate = newDate
                // If end date exists and is before new start, adjust it
                if let end = endDate, end <= newDate {
                    endDate = newDate.addingTimeInterval(3600)
                }
            }

        case .endTime:
            // Keep the date from endDate, but change the time
            if endDate != nil {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: tempDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: endDate!)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                if let newDate = calendar.date(from: dateComponents) {
                    // Ensure end time is after start time
                    if newDate > startDate {
                        endDate = newDate
                    }
                }
            }

        default:
            break
        }
    }
}

// MARK: - Preview

#Preview("Date Time Picker Content - Basic") {
    ZStack(alignment: .bottom) {
        Color(hex: "F2F2F7")
            .ignoresSafeArea()

        DateTimePickerSheetContent(
            startDate: .constant(Date()),
            endDate: .constant(nil),
            isAllDay: .constant(false),
            hasSelectedDate: .constant(false),
            onDismiss: {}
        )
    }
}

#Preview("Date Time Picker Content - With End Date") {
    ZStack(alignment: .bottom) {
        Color(hex: "F2F2F7")
            .ignoresSafeArea()

        DateTimePickerSheetContent(
            startDate: .constant(Date()),
            endDate: .constant(Date().addingTimeInterval(172800)),
            isAllDay: .constant(false),
            hasSelectedDate: .constant(false),
            onDismiss: {}
        )
    }
}

#Preview("Date Time Picker Content - All Day") {
    ZStack(alignment: .bottom) {
        Color(hex: "F2F2F7")
            .ignoresSafeArea()

        DateTimePickerSheetContent(
            startDate: .constant(Date()),
            endDate: .constant(Date().addingTimeInterval(172800)),
            isAllDay: .constant(true),
            hasSelectedDate: .constant(false),
            onDismiss: {}
        )
    }
}

// MARK: - Simple Date Picker Overlay (Reusable)
/// A reusable date-only picker overlay with AI Event Planner style animation.
/// Usage:
/// ```
/// @State private var showDatePicker = false
/// @State private var selectedDate = Date()
///
/// .overlay {
///     if showDatePicker {
///         DatePickerOverlay(
///             selectedDate: $selectedDate,
///             minDate: eventDate,
///             isPresented: $showDatePicker
///         )
///     }
/// }
/// ```

struct DatePickerOverlay: View {
    @Binding var selectedDate: Date
    var minDate: Date? = nil
    @Binding var isPresented: Bool
    var title: String = "Select Date"

    @Environment(\.colorScheme) private var colorScheme

    @State private var sheetOffset: CGFloat = 1000
    @State private var backgroundOpacity: Double = 0

    // MARK: - Theme Colors

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var closeButtonColor: Color {
        colorScheme == .dark ? Color(hex: "5A5A5E") : Color(hex: "C7C7CC")
    }

    private var purpleColor: Color {
        Color(hex: "8251EB")
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack {
                Spacer()
                sheetContent
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

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.26)

                Spacer()

                RDCloseButton { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Calendar picker
            Group {
                if let minDate = minDate {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: minDate...,
                        displayedComponents: .date
                    )
                } else {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                }
            }
            .datePickerStyle(.graphical)
            .tint(purpleColor)
            .padding(.horizontal, 16)

            Spacer()

            // Confirm button
            Button {
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(purpleColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .frame(height: 480)
        .background(backgroundColor)
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sheetOffset = 1000
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

#Preview("Date Picker Overlay") {
    ZStack {
        Color.gray.opacity(0.3)
        DatePickerOverlay(
            selectedDate: .constant(Date()),
            minDate: Date(),
            isPresented: .constant(true)
        )
    }
}

#Preview("Date Time Picker Sheet - Basic") {
    DateTimePickerSheet(
        startDate: .constant(Date()),
        endDate: .constant(nil),
        isAllDay: .constant(false),
        hasSelectedDate: .constant(false)
    )
}

#Preview("Date Time Picker - With End Date") {
    DateTimePickerSheet(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(172800)),
        isAllDay: .constant(false),
        hasSelectedDate: .constant(false)
    )
}

#Preview("Date Time Picker - All Day") {
    DateTimePickerSheet(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(172800)),
        isAllDay: .constant(true),
        hasSelectedDate: .constant(false)
    )
}

#Preview("Date Time Picker - Dark Mode") {
    DateTimePickerSheet(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(172800)),
        isAllDay: .constant(false),
        hasSelectedDate: .constant(false)
    )
    .preferredColorScheme(.dark)
}
