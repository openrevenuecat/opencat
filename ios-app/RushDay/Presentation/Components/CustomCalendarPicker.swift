import SwiftUI

// MARK: - Theme-aware Colors

private struct DateCellColors {
    let colorScheme: ColorScheme

    // Selected date background - purple
    var selectedBackground: Color {
        colorScheme == .dark ? Color(hex: "8251EB").opacity(0.3) : Color(hex: "EAE8FF")
    }
    // Selected/today text - purple
    var selectedText: Color { Color(hex: "8251EB") }
    // Range highlight text
    var rangeText: Color { Color(hex: "A17BF4") }
    // Disabled dates
    var disabledText: Color {
        colorScheme == .dark ? Color(hex: "5C5C5C") : Color(hex: "D1D5DC")
    }
    // Outside current month
    var outsideMonthText: Color {
        colorScheme == .dark ? Color(hex: "6B6B6B") : Color(hex: "8D8A95")
    }
    // Normal date text
    var normalText: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }
    // Header text (month/year)
    var headerText: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }
    // Accent color for navigation arrows - always purple
    var accentColor: Color { Color(hex: "8251EB") }
    // Weekday header text
    var weekdayText: Color {
        colorScheme == .dark ? Color(hex: "8D8A95") : Color(hex: "8D8A95")
    }
}

// MARK: - Custom Calendar Picker (Matches Figma Design)

struct CustomCalendarPicker: View {
    @Binding var selectedDate: Date
    let minimumDate: Date?
    let maximumDate: Date?     // Optional maximum selectable date
    let rangeStartDate: Date?  // Optional start date for range (when editing end date)
    let rangeEndDate: Date?    // Optional end date for range (when editing start date)
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var displayedMonth: Date
    @State private var showMonthPicker = false
    @State private var pickerSelectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var pickerSelectedYear: Int = Calendar.current.component(.year, from: Date())

    // Theme-aware colors
    private var colors: DateCellColors { DateCellColors(colorScheme: colorScheme) }

    // For TabView paging - use month identifier
    @State private var selectedMonthIndex: Int = 1  // 0=prev, 1=current, 2=next

    // For smooth month transition
    private let calendarWidth: CGFloat = 304  // Width of calendar grid area

    private let calendar = Calendar.current
    private let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // English month names for consistent UI regardless of device locale
    private var englishMonthSymbols: [String] {
        var englishCalendar = Calendar(identifier: .gregorian)
        englishCalendar.locale = Locale(identifier: "en_US")
        return englishCalendar.monthSymbols
    }

    init(selectedDate: Binding<Date>, minimumDate: Date? = nil, maximumDate: Date? = nil, rangeStartDate: Date? = nil, rangeEndDate: Date? = nil, onDismiss: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.rangeStartDate = rangeStartDate
        self.rangeEndDate = rangeEndDate
        self.onDismiss = onDismiss
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        var days: [Date?] = []

        // Get first day of month
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return days
        }

        // Get weekday of first day (1 = Sunday, 2 = Monday, etc)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        // Convert to Monday-based (0 = Monday, 6 = Sunday)
        let mondayBasedWeekday = (firstWeekday + 5) % 7

        // Add previous month's trailing days
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth)!
            let prevMonthRange = calendar.range(of: .day, in: .month, for: previousMonth)!
            let prevMonthDays = prevMonthRange.count

            for i in (prevMonthDays - mondayBasedWeekday + 1)...prevMonthDays {
                var comps = calendar.dateComponents([.year, .month], from: previousMonth)
                comps.day = i
                days.append(calendar.date(from: comps))
            }
        }

        // Add current month's days
        for day in range {
            var comps = components
            comps.day = day
            days.append(calendar.date(from: comps))
        }

        // Add next month's leading days to complete grid (6 rows = 42 cells)
        let remaining = 42 - days.count
        if remaining > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)!
            for i in 1...remaining {
                var comps = calendar.dateComponents([.year, .month], from: nextMonth)
                comps.day = i
                days.append(calendar.date(from: comps))
            }
        }

        return days
    }

    private func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }

    private func isDateDisabled(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let dateToCheck = calendar.startOfDay(for: date)

        // Always disable dates before today
        if dateToCheck < today {
            return true
        }

        // Check against minimumDate if provided
        if let minDate = minimumDate {
            if dateToCheck < calendar.startOfDay(for: minDate) {
                return true
            }
        }

        // Check against maximumDate if provided
        if let maxDate = maximumDate {
            if dateToCheck > calendar.startOfDay(for: maxDate) {
                return true
            }
        }

        return false
    }

    private func isInRange(_ date: Date) -> Bool {
        let current = calendar.startOfDay(for: date)

        // Case 1: Editing start date - range from selectedDate to rangeEndDate
        if let endDate = rangeEndDate {
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.startOfDay(for: endDate)
            return current > start && current < end
        }

        // Case 2: Editing end date - range from rangeStartDate to selectedDate
        if let startDate = rangeStartDate {
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: selectedDate)
            return current > start && current < end
        }

        return false
    }

    private func isRangeStart(_ date: Date) -> Bool {
        // Case 1: Editing start date - selectedDate is the start
        if rangeEndDate != nil {
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
        // Case 2: Editing end date - rangeStartDate is the start
        if let startDate = rangeStartDate {
            return calendar.isDate(date, inSameDayAs: startDate)
        }
        return false
    }

    private func isRangeEnd(_ date: Date) -> Bool {
        // Case 1: Editing start date - rangeEndDate is the end
        if let endDate = rangeEndDate {
            return calendar.isDate(date, inSameDayAs: endDate)
        }
        // Case 2: Editing end date - selectedDate is the end
        if rangeStartDate != nil {
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with month/year and navigation
            calendarHeader

            // Divider
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "3C3C3E") : Color(hex: "F4F4F6"))
                .frame(height: 1)

            if showMonthPicker {
                // Show month/year wheel picker
                monthYearPicker
                    .transition(.opacity)
            } else {
                // Week day headers (fixed - don't scroll)
                weekDayHeaders
                    .padding(.horizontal, 16)

                // Calendar grid with TabView for native smooth scrolling
                TabView(selection: $selectedMonthIndex) {
                    // Previous month
                    calendarGrid(for: calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth)
                        .tag(0)

                    // Current month
                    calendarGrid(for: displayedMonth)
                        .tag(1)

                    // Next month
                    calendarGrid(for: calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 282)
                .onChange(of: selectedMonthIndex) { _, newIndex in
                    if newIndex == 0 {
                        // Swiped to previous month
                        let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            displayedMonth = newMonth
                            updateSelectedDateToMonth(newMonth)
                            selectedMonthIndex = 1
                        }
                    } else if newIndex == 2 {
                        // Swiped to next month
                        let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            displayedMonth = newMonth
                            updateSelectedDateToMonth(newMonth)
                            selectedMonthIndex = 1
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
            .frame(width: 336)
            .background(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color(hex: "3C3C3E") : Color(hex: "F3F3F4"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.04), radius: 32, x: 0, y: 32)
            .shadow(color: Color.black.opacity(0.04), radius: 64, x: 0, y: 64)
    }

    // MARK: - Month Year Picker

    // Get the range of valid years based on min/max dates
    private var validYearRange: ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: Date())
        let minYear = currentYear
        let maxYear: Int
        if let maxDate = maximumDate {
            maxYear = calendar.component(.year, from: maxDate)
        } else {
            maxYear = currentYear + 10
        }
        return minYear...max(minYear, maxYear)
    }

    // Get the range of valid months for the selected year
    private var validMonthRange: ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        var minMonth = 1
        var maxMonth = 12

        // If selected year is current year, can't go before current month
        if pickerSelectedYear == currentYear {
            minMonth = currentMonth
        }

        // If selected year is max year, can't go after max month
        if let maxDate = maximumDate {
            let maxYear = calendar.component(.year, from: maxDate)
            if pickerSelectedYear == maxYear {
                maxMonth = calendar.component(.month, from: maxDate)
            }
        }

        return minMonth...max(minMonth, maxMonth)
    }

    private var monthYearPicker: some View {
        HStack(spacing: 0) {
            // Month picker - limited by validMonthRange
            Picker("Month", selection: $pickerSelectedMonth) {
                ForEach(validMonthRange, id: \.self) { month in
                    Text(englishMonthSymbols[month - 1])
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            // Year picker - limited by validYearRange
            Picker("Year", selection: $pickerSelectedYear) {
                ForEach(validYearRange, id: \.self) { year in
                    Text(String(year))
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
            .clipped()
        }
        .frame(height: 280)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onChange(of: pickerSelectedMonth) { _, newMonth in
            updateDisplayedMonth(month: newMonth, year: pickerSelectedYear)
            updateSelectedDateToNewMonthYear(month: newMonth, year: pickerSelectedYear)
        }
        .onChange(of: pickerSelectedYear) { _, newYear in
            // When year changes, clamp month to valid range
            let newValidRange = getValidMonthRangeForYear(newYear)
            let clampedMonth = min(max(pickerSelectedMonth, newValidRange.lowerBound), newValidRange.upperBound)
            if clampedMonth != pickerSelectedMonth {
                pickerSelectedMonth = clampedMonth
            }
            updateDisplayedMonth(month: clampedMonth, year: newYear)
            updateSelectedDateToNewMonthYear(month: clampedMonth, year: newYear)
        }
        .onAppear {
            pickerSelectedMonth = calendar.component(.month, from: displayedMonth)
            pickerSelectedYear = calendar.component(.year, from: displayedMonth)
        }
    }

    // Helper to get valid month range for a specific year
    private func getValidMonthRangeForYear(_ year: Int) -> ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        var minMonth = 1
        var maxMonth = 12

        if year == currentYear {
            minMonth = currentMonth
        }

        if let maxDate = maximumDate {
            let maxYear = calendar.component(.year, from: maxDate)
            if year == maxYear {
                maxMonth = calendar.component(.month, from: maxDate)
            }
        }

        return minMonth...max(minMonth, maxMonth)
    }

    private func updateDisplayedMonth(month: Int, year: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        if let newDate = calendar.date(from: components) {
            displayedMonth = newDate
        }
    }

    /// Update selectedDate to the same day in the new month/year
    /// If the day doesn't exist (e.g., Jan 31 -> Feb), clamp to last day of month
    private func updateSelectedDateToNewMonthYear(month: Int, year: Int) {
        let currentDay = calendar.component(.day, from: selectedDate)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        // Get the last day of the target month
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return
        }

        // Clamp the day to valid range for this month
        let clampedDay = min(currentDay, range.count)
        components.day = clampedDay

        if let newDate = calendar.date(from: components) {
            // Only update if the new date is valid (not before minimum date)
            if !isDateDisabled(newDate) {
                selectedDate = newDate
            }
        }
    }

    /// Update selectedDate when navigating to a new month (via chevrons or swipe)
    /// Keeps the same day if valid, otherwise clamps to last day of month
    private func updateSelectedDateToMonth(_ newMonth: Date) {
        let month = calendar.component(.month, from: newMonth)
        let year = calendar.component(.year, from: newMonth)
        updateSelectedDateToNewMonthYear(month: month, year: year)
    }

    // MARK: - Calendar Header

    // Check if we can navigate to previous month
    private var canGoToPreviousMonth: Bool {
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let displayMonth = calendar.component(.month, from: displayedMonth)
        let displayYear = calendar.component(.year, from: displayedMonth)

        // Can't go before current month/year
        if displayYear < currentYear { return false }
        if displayYear == currentYear && displayMonth <= currentMonth { return false }
        return true
    }

    // Check if we can navigate to next month
    private var canGoToNextMonth: Bool {
        guard let maxDate = maximumDate else { return true }

        let maxMonth = calendar.component(.month, from: maxDate)
        let maxYear = calendar.component(.year, from: maxDate)
        let displayMonth = calendar.component(.month, from: displayedMonth)
        let displayYear = calendar.component(.year, from: displayedMonth)

        // Can't go after max month/year
        if displayYear > maxYear { return false }
        if displayYear == maxYear && displayMonth >= maxMonth { return false }
        return true
    }

    private var calendarHeader: some View {
        HStack {
            // Month/Year with dropdown indicator
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showMonthPicker.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(monthYearText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(colors.headerText)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.accentColor)
                        .rotationEffect(.degrees(showMonthPicker ? 90 : 0))
                }
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                // Previous month button
                Button {
                    goToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(canGoToPreviousMonth ? (colorScheme == .dark ? .white : colors.accentColor) : Color(hex: "D1D5DC"))
                        .frame(width: 40, height: 40)
                        .background(canGoToPreviousMonth ? (colorScheme == .dark ? Color(hex: "8251EB") : .white) : (colorScheme == .dark ? Color(hex: "3C3C3E") : Color(hex: "F5F5F5")))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? Color(hex: "9261FB").opacity(canGoToPreviousMonth ? 1 : 0.3) : Color(hex: "ECECED"), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "110C22").opacity(0.08), radius: 1, x: 0, y: 1)
                }
                .disabled(!canGoToPreviousMonth)

                // Next month button
                Button {
                    goToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(canGoToNextMonth ? (colorScheme == .dark ? .white : colors.accentColor) : Color(hex: "D1D5DC"))
                        .frame(width: 40, height: 40)
                        .background(canGoToNextMonth ? (colorScheme == .dark ? Color(hex: "8251EB") : .white) : (colorScheme == .dark ? Color(hex: "3C3C3E") : Color(hex: "F5F5F5")))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? Color(hex: "9261FB").opacity(canGoToNextMonth ? 1 : 0.3) : Color(hex: "ECECED"), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "110C22").opacity(0.08), radius: 1, x: 0, y: 1)
                }
                .disabled(!canGoToNextMonth)
            }
        }
        .padding(16)
    }

    // MARK: - Week Day Headers

    private var weekDayHeaders: some View {
        HStack(spacing: 4) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(colors.weekdayText)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - Calendar Grid (for a specific month)

    private func calendarGrid(for month: Date) -> some View {
        let days = daysInMonthFor(month)

        return VStack(alignment: .center, spacing: 7) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        if index < days.count, let date = days[index] {
                            dateCellButton(for: date, inMonth: month)
                        } else {
                            Color.clear.frame(width: 40, height: 40)
                        }
                    }
                }
            }
        }
        .frame(width: calendarWidth)
    }

    // Get days for a specific month (not just displayedMonth)
    private func daysInMonthFor(_ month: Date) -> [Date?] {
        var days: [Date?] = []

        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return days
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let mondayBasedWeekday = (firstWeekday + 5) % 7

        // Previous month's trailing days
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth)!
            let prevMonthRange = calendar.range(of: .day, in: .month, for: previousMonth)!
            let prevMonthDays = prevMonthRange.count

            for i in (prevMonthDays - mondayBasedWeekday + 1)...prevMonthDays {
                var comps = calendar.dateComponents([.year, .month], from: previousMonth)
                comps.day = i
                days.append(calendar.date(from: comps))
            }
        }

        // Current month's days
        for day in range {
            var comps = components
            comps.day = day
            days.append(calendar.date(from: comps))
        }

        // Next month's leading days
        let remaining = 42 - days.count
        if remaining > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)!
            for i in 1...remaining {
                var comps = calendar.dateComponents([.year, .month], from: nextMonth)
                comps.day = i
                days.append(calendar.date(from: comps))
            }
        }

        return days
    }

    private func isInCurrentMonthFor(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    // MARK: - Month Navigation

    private func goToPreviousMonth() {
        withAnimation {
            selectedMonthIndex = 0
        }
    }

    private func goToNextMonth() {
        withAnimation {
            selectedMonthIndex = 2
        }
    }

    // MARK: - Date Cell Button

    private func dateCellButton(for date: Date, inMonth: Date? = nil) -> some View {
        let monthToCheck = inMonth ?? displayedMonth
        let inCurrentMonth = isInCurrentMonthFor(date, month: monthToCheck)
        let today = isToday(date)
        let selected = isSelected(date)
        let weekend = isWeekend(date)
        let disabled = isDateDisabled(date)
        let inRange = isInRange(date)
        let rangeStart = isRangeStart(date)
        let rangeEnd = isRangeEnd(date)

        let day = calendar.component(.day, from: date)

        return Button {
            guard !disabled else { return }
            selectedDate = date
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onDismiss()
        } label: {
            Text("\(day)")
                .font(.system(size: 20, weight: selected || today || rangeStart || rangeEnd ? .semibold : .regular))
                .foregroundColor(dateTextColor(
                    inCurrentMonth: inCurrentMonth,
                    today: today,
                    selected: selected,
                    weekend: weekend,
                    disabled: disabled,
                    inRange: inRange,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ))
                .frame(width: 40, height: 40)
                .background(
                    (selected || rangeStart || rangeEnd) ? colors.selectedBackground : Color.clear
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func dateTextColor(inCurrentMonth: Bool, today: Bool, selected: Bool, weekend: Bool, disabled: Bool, inRange: Bool, rangeStart: Bool, rangeEnd: Bool) -> Color {
        if disabled {
            return colors.disabledText
        }
        if selected || rangeStart || rangeEnd {
            return colors.selectedText
        }
        if inRange && inCurrentMonth {
            return colors.rangeText
        }
        if !inCurrentMonth {
            return colors.outsideMonthText
        }
        if today {
            return colors.selectedText
        }
        return colors.normalText
    }
}

// MARK: - Preview

#Preview("Custom Calendar Picker") {
    ZStack {
        Color.black.opacity(0.2)
            .ignoresSafeArea()

        CustomCalendarPicker(
            selectedDate: .constant(Date()),
            onDismiss: {}
        )
    }
}

#Preview("Custom Calendar Picker - Dark Mode") {
    ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()

        CustomCalendarPicker(
            selectedDate: .constant(Date()),
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}
