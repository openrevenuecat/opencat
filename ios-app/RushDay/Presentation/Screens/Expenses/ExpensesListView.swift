import SwiftUI
import Combine

// MARK: - Expense Tab
enum ExpenseTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case planned = "Planned"
    case spent = "Spent"

    var id: String { rawValue }
}

// MARK: - Expenses List View
/// Design reference: Figma node 301:36415 (Overview), 301:37595 (Planned), 301:37444 (Spent)
struct ExpensesListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddExpense = false
    @State private var selectedTab: ExpenseTab = .overview
    @State private var expenseToEdit: Expense?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var hasAppearedOnce = false

    private let eventId: String

    init(eventId: String) {
        self.eventId = eventId
        // Initialize with nil appState - will be set in onAppear
        _viewModel = StateObject(wrappedValue: ExpensesViewModel(eventId: eventId, appState: nil))
    }

    private var navigationTitle: String {
        if viewModel.isMultiSelectEnabled {
            if viewModel.selectedExpenses.isEmpty {
                return "Select Expenses"
            } else {
                return "\(viewModel.selectedExpenses.count) Selected"
            }
        }
        return L10n.expenses
    }

    // Check if there are any spent (paid) expenses
    private var hasSpentExpenses: Bool {
        viewModel.expenses.contains { $0.paymentStatus == .paid }
    }

    // Check if there are any planned (pending) expenses
    private var hasPlannedExpenses: Bool {
        viewModel.expenses.contains { $0.paymentStatus == .pending }
    }

    // Show segmented control if there are any expenses (spent OR planned)
    private var shouldShowSegmentedControl: Bool {
        hasSpentExpenses || hasPlannedExpenses
    }

    // MARK: - Filtered Expenses
    private var filteredExpenses: [Expense] {
        switch selectedTab {
        case .overview:
            // Pending expenses first (sorted by createdAt desc), then paid expenses at bottom
            let pending = viewModel.expenses
                .filter { $0.paymentStatus == .pending }
                .sorted { $0.createdAt > $1.createdAt }
            let paid = viewModel.expenses
                .filter { $0.paymentStatus == .paid }
                .sorted { $0.createdAt > $1.createdAt }
            return pending + paid
        case .planned:
            return viewModel.expenses.filter { $0.paymentStatus == .pending }
        case .spent:
            return viewModel.expenses.filter { $0.paymentStatus == .paid }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Custom header with SF Pro Rounded
                HStack {
                    Text(navigationTitle)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(textPrimaryColor)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Shimmer logic: show shimmer while loading
                if viewModel.isLoading {
                    // Loading - show shimmer
                    ScrollView {
                        ExpensesShimmerView()
                    }
                    .background(backgroundColor)
                } else if viewModel.isMultiSelectEnabled {
                    // Multi-select mode: Just show expense list, no tabs/summary
                    ScrollView {
                        multiSelectContent
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .padding(.bottom, 100)
                    }
                    .background(backgroundColor)
                } else {
                    // Show segmented control if there are any expenses (spent or planned)
                    if shouldShowSegmentedControl {
                        ExpenseSegmentedControl(selectedTab: $selectedTab)
                            .padding(.horizontal, 16)
                            .background(backgroundColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Always use ScrollView for consistent structure (avoid TabView rebuild)
                    ScrollView {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .padding(.bottom, 80)
                        case .planned:
                            plannedContent
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .padding(.bottom, 80)
                        case .spent:
                            spentContent
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .padding(.bottom, 80)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
            }
            .background(backgroundColor)
            .animation(hasAppearedOnce ? .easeInOut(duration: 0.25) : nil, value: hasSpentExpenses)

            // Bottom toolbar when in select mode
            if viewModel.isMultiSelectEnabled {
                SelectModeToolbar(
                    isAllSelected: viewModel.selectedExpenses.count == viewModel.expenses.count && !viewModel.expenses.isEmpty,
                    hasSelection: !viewModel.selectedExpenses.isEmpty,
                    showCompleteButton: false,
                    canComplete: false,
                    onSelectAll: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            if viewModel.selectedExpenses.count == viewModel.expenses.count {
                                viewModel.selectedExpenses.removeAll()
                            } else {
                                viewModel.selectedExpenses = Set(viewModel.expenses.map { $0.id })
                            }
                        }
                    },
                    onDelete: {
                        if !viewModel.selectedExpenses.isEmpty {
                            showDeleteConfirmation = true
                        }
                    },
                    onComplete: nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isMultiSelectEnabled {
                    SelectModeCheckmarkButton(hasSelection: !viewModel.selectedExpenses.isEmpty) {
                        viewModel.isMultiSelectEnabled = false
                        viewModel.selectedExpenses.removeAll()
                    }
                    .id(viewModel.selectedExpenses.count)
                } else if !viewModel.expenses.isEmpty {
                    Menu {
                        Button {
                            viewModel.isMultiSelectEnabled = true
                        } label: {
                            Label("Select Expenses", systemImage: "checkmark.circle")
                        }

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label {
                                Text("Delete All")
                            } icon: {
                                Image("icon_bin_red")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(textPrimaryColor)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.isMultiSelectEnabled {
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(FloatingAddButtonStyle())
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(eventId: viewModel.eventId) { expense in
                viewModel.addExpense(expense)
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            EditExpenseSheet(
                expense: expense,
                onSave: { updated in
                    viewModel.updateExpense(updated)
                },
                onDelete: { expenseId in
                    viewModel.deleteExpense(expenseId)
                }
            )
        }
        .sheet(isPresented: $viewModel.showBudgetEditor) {
            BudgetEditorSheet(
                currentBudget: viewModel.plannedBudget,
                onSave: { newBudget in
                    viewModel.updateBudget(newBudget)
                }
            )
        }
        .alert("Delete \(viewModel.selectedExpenses.count) Expenses?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedExpenses()
            }
        } message: {
            Text("All selected expenses will be permanently deleted")
        }
        .alert("Delete All Expenses?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllExpenses()
            }
        } message: {
            Text("All Expenses will be permanently deleted")
        }
        .onAppear {
            // Check cache state and set loading appropriately on each visit
            viewModel.setAppState(appState)
        }
        .task {
            // Load fresh data from backend
            await viewModel.loadExpenses()
            // Enable animations only after initial load
            hasAppearedOnce = true
        }
        .onChange(of: hasSpentExpenses) { _, hasSpent in
            // Reset to overview tab when no spent expenses (avoid empty tab)
            if !hasSpent && selectedTab == .spent {
                selectedTab = .overview
            }
        }
        .onChange(of: hasPlannedExpenses) { _, hasPlanned in
            // Reset to overview tab when no planned expenses (avoid empty tab)
            if !hasPlanned && selectedTab == .planned {
                selectedTab = .overview
            }
        }
    }

    // MARK: - Overview Tab Content
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Full Budget Summary Card
            ExpenseBudgetCard(
                budget: viewModel.plannedBudget,
                plannedExpenses: viewModel.totalPlanned,
                remaining: viewModel.remaining,
                totalSpent: viewModel.totalSpent,
                onBudgetTap: { viewModel.showBudgetEditor = true }
            )

            // Expense List with radio buttons/checkmarks
            if !filteredExpenses.isEmpty {
                ExpenseListCard(
                    expenses: filteredExpenses,
                    displayMode: .overview,
                    isMultiSelectEnabled: viewModel.isMultiSelectEnabled,
                    selectedExpenses: viewModel.selectedExpenses,
                    onCheckboxTapped: { expense in
                        if viewModel.isMultiSelectEnabled {
                            viewModel.toggleExpenseSelection(expense.id)
                        } else {
                            viewModel.toggleExpenseStatus(expense)
                        }
                    },
                    onRowTapped: { expense in
                        expenseToEdit = expense
                    }
                )
            }
        }
    }

    // MARK: - Planned Tab Content
    /// Design reference: Figma node 301:37595
    private var plannedContent: some View {
        VStack(spacing: 16) {
            // Planned Expenses Summary Card (single row with clipboard icon)
            PlannedExpensesSummaryCard(amount: viewModel.totalPlanned)

            // Expense List with radio buttons (empty circles)
            if !filteredExpenses.isEmpty {
                ExpenseListCard(
                    expenses: filteredExpenses,
                    displayMode: .planned,
                    isMultiSelectEnabled: viewModel.isMultiSelectEnabled,
                    selectedExpenses: viewModel.selectedExpenses,
                    onCheckboxTapped: { expense in
                        if viewModel.isMultiSelectEnabled {
                            viewModel.toggleExpenseSelection(expense.id)
                        } else {
                            viewModel.toggleExpenseStatus(expense)
                        }
                    },
                    onRowTapped: { expense in
                        expenseToEdit = expense
                    }
                )
            }
        }
    }

    // MARK: - Spent Tab Content
    /// Design reference: Figma node 301:37444
    private var spentContent: some View {
        VStack(spacing: 16) {
            // Total Spent Summary Card (single row, no icon)
            TotalSpentSummaryCard(amount: viewModel.totalSpent)

            // Expense List WITHOUT radio buttons - just plain text rows
            if !filteredExpenses.isEmpty {
                ExpenseListCard(
                    expenses: filteredExpenses,
                    displayMode: .spent,
                    isMultiSelectEnabled: viewModel.isMultiSelectEnabled,
                    selectedExpenses: viewModel.selectedExpenses,
                    onCheckboxTapped: { expense in
                        if viewModel.isMultiSelectEnabled {
                            viewModel.toggleExpenseSelection(expense.id)
                        }
                        // No toggle status in spent tab - items are already paid
                    },
                    onRowTapped: { expense in
                        expenseToEdit = expense
                    }
                )
            }
        }
    }

    // MARK: - Multi-Select Content
    /// Design reference: Figma node 301:37970 - Just expense list, reusing existing card
    private var multiSelectContent: some View {
        VStack(spacing: 16) {
            if !viewModel.expenses.isEmpty {
                // Use same sorting as filteredExpenses (pending first, then paid)
                let sortedExpenses = {
                    let pending = viewModel.expenses
                        .filter { $0.paymentStatus == .pending }
                        .sorted { $0.createdAt > $1.createdAt }
                    let paid = viewModel.expenses
                        .filter { $0.paymentStatus == .paid }
                        .sorted { $0.createdAt > $1.createdAt }
                    return pending + paid
                }()

                ExpenseListCard(
                    expenses: sortedExpenses,
                    displayMode: .overview,
                    isMultiSelectEnabled: true,
                    selectedExpenses: viewModel.selectedExpenses,
                    onCheckboxTapped: { expense in
                        viewModel.toggleExpenseSelection(expense.id)
                    },
                    onRowTapped: { expense in
                        viewModel.toggleExpenseSelection(expense.id)
                    }
                )
            }
        }
    }


    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color.rdBackground
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .rdTextPrimary
    }
}

// MARK: - Expense Segmented Control
/// Design reference: Figma node 301:36420
struct ExpenseSegmentedControl: View {
    @Binding var selectedTab: ExpenseTab

    private let selectedColor = Color(hex: "8251EB")
    private let unselectedColor = Color(hex: "9E9EAA")

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                ForEach(ExpenseTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 9) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                .tracking(-0.23)
                                .foregroundColor(selectedTab == tab ? selectedColor : unselectedColor)

                            // Underline that matches text width
                            Rectangle()
                                .fill(selectedTab == tab ? selectedColor : Color.clear)
                                .frame(height: 4)
                                .cornerRadius(2)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)

            // Bottom border - 0.33px #9E9EAA per Figma
            Rectangle()
                .fill(unselectedColor)
                .frame(height: 0.33)
        }
    }
}

// MARK: - Expense Budget Card
/// Design reference: Figma budget summary
struct ExpenseBudgetCard: View {
    let budget: Double
    let plannedExpenses: Double
    let remaining: Double
    let totalSpent: Double
    let onBudgetTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Budget row
            BudgetRowView(
                iconName: "budget_icon",
                title: "Budget",
                value: formatCurrency(budget),
                valueColor: .rdPrimary,
                onTap: onBudgetTap
            )

            divider

            // Planned Expenses row
            BudgetRowView(
                iconName: "planned_icon",
                title: "Planned Expenses",
                value: formatCurrency(plannedExpenses),
                valueColor: .rdPrimary
            )

            divider

            // Remaining row
            BudgetRowView(
                iconName: "remaining_icon",
                title: "Remaining",
                value: formatCurrency(remaining),
                valueColor: .rdPrimary
            )

            divider

            // Total Spent row
            HStack {
                Text("Total Spent")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textPrimaryColor)

                Spacer()

                Text(formatSpentCurrency(totalSpent))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.rdWarning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(cardBackground)
        .cornerRadius(12)
    }

    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 0.33)
            .padding(.leading, 16)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color(hex: "181818").opacity(0.24)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(formatted)$"
    }

    private func formatSpentCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "-\(formatted)$"
    }
}

// MARK: - Budget Row View
private struct BudgetRowView: View {
    let iconName: String
    let title: String
    let value: String
    let valueColor: Color
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let onTap = onTap {
            Button {
                onTap()
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            // Icon
            BudgetIconView(iconName: iconName)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(textPrimaryColor)

            Spacer()

            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// MARK: - Budget Icon View
private struct BudgetIconView: View {
    let iconName: String

    var body: some View {
        Image(iconName)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.rdPrimary)
    }
}

// MARK: - Expense Display Mode
enum ExpenseDisplayMode {
    case overview  // Shows radio buttons/checkmarks based on payment status
    case planned   // Shows only empty radio circles (all pending)
    case spent     // Shows NO radio buttons - just plain text rows
}

// MARK: - Planned Expenses Summary Card
/// Design reference: Figma node 301:37595 - Single row card for Planned tab
struct PlannedExpensesSummaryCard: View {
    let amount: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Clipboard list icon
            Image("planned_icon")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.rdPrimary)

            Text("Planned Expenses")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.44)

            Spacer()

            Text(formatCurrency(amount))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.rdPrimary)
                .tracking(-0.44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(12)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(formatted)$"
    }
}

// MARK: - Total Spent Summary Card
/// Design reference: Figma node 301:37444 - Single row card for Spent tab (NO icon)
struct TotalSpentSummaryCard: View {
    let amount: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text("Total Spent")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.44)

            Spacer()

            Text(formatSpentCurrency(amount))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.rdWarning)
                .tracking(-0.44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(12)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private func formatSpentCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "-\(formatted)$"
    }
}

// MARK: - Expense List Card
struct ExpenseListCard: View {
    let expenses: [Expense]
    let displayMode: ExpenseDisplayMode
    let isMultiSelectEnabled: Bool
    let selectedExpenses: Set<String>
    let onCheckboxTapped: (Expense) -> Void  // For toggling status
    let onRowTapped: (Expense) -> Void       // For opening edit sheet

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                ExpenseItemRow(
                    expense: expense,
                    displayMode: displayMode,
                    isMultiSelectEnabled: isMultiSelectEnabled,
                    isSelected: selectedExpenses.contains(expense.id),
                    onCheckboxTapped: { onCheckboxTapped(expense) },
                    onRowTapped: { onRowTapped(expense) }
                )

                if index < expenses.count - 1 {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 0.5)
                        .padding(.leading, displayMode == .spent ? 16 : 62)
                }
            }
        }
        .background(cardBackground)
        .cornerRadius(12)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color(hex: "181818").opacity(0.24)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }
}

// MARK: - Expense Item Row
/// Design reference: Figma expense row with radio button (Overview/Planned) or plain text (Spent)
struct ExpenseItemRow: View {
    let expense: Expense
    let displayMode: ExpenseDisplayMode
    let isMultiSelectEnabled: Bool
    let isSelected: Bool
    let onCheckboxTapped: () -> Void  // For toggling status
    let onRowTapped: () -> Void       // For opening edit sheet

    @Environment(\.colorScheme) private var colorScheme

    private var isPaid: Bool {
        expense.paymentStatus == .paid
    }

    var body: some View {
        HStack(spacing: 12) {
            // Radio button / Checkmark (only for overview and planned modes)
            // Expanded tap area (44x44 min) while keeping visual size at 24x24
            if displayMode != .spent {
                checkboxView
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCheckboxTapped()
                    }
            }

            // Title and Amount - tappable area for edit
            HStack {
                Text(expense.title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.44)
                    .lineLimit(1)

                Spacer()

                Text(formatAmount())
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(amountColor)
                    .tracking(-0.44)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onRowTapped()
            }
        }
        .padding(.leading, displayMode == .spent ? 16 : 6)
        .padding(.trailing, displayMode == .spent ? 12 : 16)
        .padding(.vertical, displayMode == .spent ? 11 : 0)
        .background(isMultiSelectEnabled && isSelected ? selectedBackground : Color.clear)
    }

    private var selectedBackground: Color {
        Color(hex: "9C9CA6").opacity(0.2)
    }

    @ViewBuilder
    private var checkboxView: some View {
        if isMultiSelectEnabled {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .rdPrimary : radioButtonColor)
        } else {
            switch displayMode {
            case .overview:
                if isPaid {
                    // Purple checkmark for paid (matching design)
                    ZStack {
                        Circle()
                            .fill(Color.rdPrimary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Empty radio button for pending
                    Circle()
                        .stroke(radioButtonColor, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            case .planned:
                // Always show empty radio button in planned mode
                Circle()
                    .stroke(radioButtonColor, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            case .spent:
                EmptyView()
            }
        }
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var radioButtonColor: Color {
        colorScheme == .dark ? Color(hex: "636366") : Color(hex: "C7C7CC")
    }

    private var amountColor: Color {
        switch displayMode {
        case .overview:
            return isPaid ? .rdWarning : .rdPrimary
        case .planned:
            return .rdPrimary
        case .spent:
            return .rdWarning
        }
    }

    private func formatAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: expense.amount)) ?? "0"

        switch displayMode {
        case .overview:
            return isPaid ? "-\(formatted)$" : "\(formatted)$"
        case .planned:
            return "\(formatted)$"
        case .spent:
            return "-\(formatted)$"
        }
    }
}

// MARK: - Add Expense Sheet
/// Design reference: Figma node 301:38569
struct AddExpenseSheet: View {
    let eventId: String
    let onAdd: (Expense) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title = ""
    @State private var amount = ""
    @State private var isPaid = false
    @FocusState private var isTitleFocused: Bool

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.trimmingCharacters(in: .whitespaces).isEmpty
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
                    title: "New Expense",
                    canSave: isFormValid,
                    onDismiss: { dismiss() },
                    onSave: { saveExpense() }
                )

                ScrollView {
                    VStack(spacing: 0) {
                        titleSection
                        amountSection
                        paidToggleSection
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
    }

    private var legacyContent: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            titleSection
                            amountSection
                            paidToggleSection
                        }
                        .padding(.bottom, 24)
                    }

                    // Add Button (only for pre-iOS 26)
                    addButton
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
    }

    private func saveExpense() {
        let expense = Expense(
            eventId: eventId,
            title: title,
            category: .other,
            amount: Double(amount) ?? 0,
            paymentStatus: isPaid ? .paid : .pending,
            notes: nil,
            createdBy: DIContainer.shared.authService.currentUser?.id ?? ""
        )
        onAdd(expense)
        dismiss()
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TITLE")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color.black)
                .tracking(-0.13)
                .textCase(.uppercase)
                .frame(height: 30, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            TextField("Name", text: $title)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.44)
                .foregroundColor(textPrimaryColor)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit {
                    isTitleFocused = false
                }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Amount Section
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AMOUNT")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8E8E93") : Color.black)
                .tracking(-0.13)
                .textCase(.uppercase)
                .frame(height: 30, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            TextField("0", text: $amount)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.44)
                .foregroundColor(textPrimaryColor)
                .keyboardType(.decimalPad)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Paid Toggle Section
    private var paidToggleSection: some View {
        HStack {
            Text("Set as paid")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.44)

            Spacer()

            Toggle("", isOn: $isPaid)
                .tint(.rdPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Add Button (Legacy)
    private var addButton: some View {
        VStack(spacing: 0) {
            RDGradientButton(
                "Add",
                isEnabled: isFormValid,
                action: { saveExpense() }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }
}

// MARK: - Edit Expense Sheet
/// Design reference: Figma node 301:38773
struct EditExpenseSheet: View {
    let expense: Expense
    let onSave: (Expense) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var amount: String
    @State private var isPaid: Bool
    @State private var showDeleteConfirmation = false
    @FocusState private var isTitleFocused: Bool

    init(expense: Expense, onSave: @escaping (Expense) -> Void, onDelete: @escaping (String) -> Void) {
        self.expense = expense
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: String(format: "%.0f", expense.amount))
        _isPaid = State(initialValue: expense.paymentStatus == .paid)
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentAmount = Double(amount) ?? 0
        let currentIsPaid = isPaid

        return trimmedTitle != expense.title ||
               currentAmount != expense.amount ||
               currentIsPaid != (expense.paymentStatus == .paid)
    }

    private var canSave: Bool {
        isFormValid && hasChanges
    }

    private func saveExpense() {
        var updated = expense
        updated.title = title
        updated.amount = Double(amount) ?? expense.amount
        updated.paymentStatus = isPaid ? .paid : .pending
        onSave(updated)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with RDSheetHeader
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    RDSheetHeader(
                        title: "Edit Expense",
                        canSave: canSave,
                        onDismiss: { dismiss() },
                        onSave: {
                            saveExpense()
                            dismiss()
                        }
                    )

                    VStack(spacing: 8) {
                        // Title Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("TITLE")

                            TextField("Enter Expense Name", text: $title)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)
                                .focused($isTitleFocused)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                        }

                        // Amount Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("AMOUNT")

                            TextField("Amount", text: $amount)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                        }

                        // Set as paid toggle
                        HStack {
                            Text("Set as paid")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)

                            Spacer()

                            Toggle("", isOn: $isPaid)
                                .tint(.rdPrimary)
                        }
                        .padding(16)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .padding(.top, 8)

                        Spacer()

                        // Delete Expense Button - red outline with trash icon
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image("icon_swipe_bin")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("Delete Expense")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "DB4F47"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "DB4F47"), lineWidth: 1)
                            )
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .alert("Delete Expense?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete(expense.id)
                    dismiss()
                }
            } message: {
                Text("This expense will be permanently deleted")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
            }
        } else {
            // Pre-iOS 26 with NavigationStack and bottom Save button
            NavigationStack {
                ZStack {
                    backgroundColor.ignoresSafeArea()

                    VStack(spacing: 8) {
                        // Title Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("TITLE")

                            TextField("Enter Expense Name", text: $title)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)
                                .focused($isTitleFocused)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                        }

                        // Amount Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("AMOUNT")

                            TextField("Amount", text: $amount)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(cardBackground)
                                .cornerRadius(12)
                        }

                        // Set as paid toggle
                        HStack {
                            Text("Set as paid")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.44)

                            Spacer()

                            Toggle("", isOn: $isPaid)
                                .tint(.rdPrimary)
                        }
                        .padding(16)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .padding(.top, 8)

                        Spacer()

                        // Delete Expense Button - red outline with trash icon
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image("icon_swipe_bin")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("Delete Expense")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "DB4F47"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "DB4F47"), lineWidth: 1)
                            )
                        }

                        // Save Button (only for pre-iOS 26)
                        Button {
                            saveExpense()
                            dismiss()
                        } label: {
                            Text("Save")
                        }
                        .rdGradientButtonStyle(isEnabled: isFormValid)
                        .disabled(!isFormValid)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .navigationTitle("Edit Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                    }
                }
                .alert("Delete Expense?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        onDelete(expense.id)
                        dismiss()
                    }
                } message: {
                    Text("This expense will be permanently deleted")
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTitleFocused = true
                    }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(labelColor)
            .tracking(-0.13)
            .textCase(.uppercase)
            .padding(.vertical, 10)
    }

    private var labelColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        Color.rdBackground
    }

    private var cardBackground: Color {
        Color.rdBackgroundSecondary
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9E9EAA") : Color(hex: "9E9EAA")
    }
}

// MARK: - Budget Editor Sheet
/// Design reference: Figma node 301:38754 (matching Add/Edit expense style)
struct BudgetEditorSheet: View {
    let currentBudget: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var budgetText: String
    @FocusState private var isBudgetFocused: Bool

    init(currentBudget: Double, onSave: @escaping (Double) -> Void) {
        self.currentBudget = currentBudget
        self.onSave = onSave
        _budgetText = State(initialValue: currentBudget > 0 ? String(format: "%.0f", currentBudget) : "")
    }

    private var isFormValid: Bool {
        !budgetText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        let newBudget = Double(budgetText.trimmingCharacters(in: .whitespaces)) ?? 0
        return newBudget != currentBudget
    }

    private var canSave: Bool {
        isFormValid && hasChanges
    }

    private func saveBudget() {
        let budget = Double(budgetText) ?? 0
        onSave(budget)
        dismiss()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Use RDSheetHeader with glass effect buttons
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    RDSheetHeader(
                        title: "Edit Budget",
                        canSave: canSave,
                        onDismiss: { dismiss() },
                        onSave: saveBudget
                    )

                    VStack(spacing: 8) {
                        // Budget Amount Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("BUDGET AMOUNT")

                            HStack {
                                TextField("Enter budget amount", text: $budgetText)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(textPrimaryColor)
                                    .tracking(-0.44)
                                    .focused($isBudgetFocused)
                                    .keyboardType(.numberPad)

                                Text("$")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(textSecondaryColor)
                            }
                            .padding(16)
                            .background(cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        // Hint text
                        Text("Set a budget to track your spending against your plan")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isBudgetFocused = true
                }
            }
        } else {
            // Pre-iOS 26: Use NavigationStack with bottom Save button
            NavigationStack {
                ZStack {
                    backgroundColor.ignoresSafeArea()

                    VStack(spacing: 8) {
                        // Budget Amount Section
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("BUDGET AMOUNT")

                            HStack {
                                TextField("Enter budget amount", text: $budgetText)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(textPrimaryColor)
                                    .tracking(-0.44)
                                    .focused($isBudgetFocused)
                                    .keyboardType(.numberPad)

                                Text("$")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(textSecondaryColor)
                            }
                            .padding(16)
                            .background(cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        // Hint text
                        Text("Set a budget to track your spending against your plan")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()

                        // Save Button (pre-iOS 26 only)
                        Button {
                            saveBudget()
                        } label: {
                            Text("Save")
                        }
                        .rdGradientButtonStyle(isEnabled: isFormValid)
                        .disabled(!isFormValid)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .navigationTitle("Edit Budget")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isBudgetFocused = true
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .tracking(-0.13)
            .textCase(.uppercase)
            .padding(.horizontal, 0)
            .padding(.vertical, 10)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color.rdBackground
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9E9EAA") : Color(hex: "9E9EAA")
    }
}

// MARK: - View Model
@MainActor
class ExpensesViewModel: ObservableObject {
    let eventId: String

    @Published var expenses: [Expense] = []
    @Published var plannedBudget: Double = 0
    @Published var isLoading = true  // Start true to show shimmer on initial load
    @Published var isInitialized = false  // Tracks if data has been loaded at least once
    @Published var isMultiSelectEnabled = false
    @Published var selectedExpenses: Set<String> = []
    @Published var showBudgetEditor = false

    private let expenseRepository: ExpenseRepositoryProtocol
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    init(eventId: String, appState: AppState? = nil) {
        self.eventId = eventId
        self.expenseRepository = DIContainer.shared.expenseRepository
        self.appState = appState

        // Load cached data from AppState immediately (no jumping)
        if let appState = appState {
            let cachedExpenses = appState.expenses(for: eventId)
            let cachedBudget = appState.budget(for: eventId)
            if !cachedExpenses.isEmpty || cachedBudget > 0 {
                self.expenses = cachedExpenses
                self.plannedBudget = cachedBudget
                self.isLoading = false
                self.isInitialized = true
            }
            subscribeToAppState(appState)
        }
    }

    /// Set AppState reference and subscribe to updates (called from View's onAppear)
    func setAppState(_ appState: AppState) {
        // Always check current cache state to determine loading
        let cachedExpenses = appState.expenses(for: eventId)
        let cachedBudget = appState.budget(for: eventId)

        if !cachedExpenses.isEmpty || cachedBudget > 0 {
            self.expenses = cachedExpenses
            self.plannedBudget = cachedBudget
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
        appState.$expensesByEvent
            .map { [eventId] in $0[eventId] ?? [] }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expenses in
                guard let self = self else { return }
                // Only update if different to avoid loops
                if self.expenses != expenses {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.expenses = expenses
                    }
                    // Reset loading state when cache is cleared (to show shimmer)
                    // But NOT if already initialized (e.g. user deleted all items)
                    if expenses.isEmpty && !self.isInitialized {
                        self.isLoading = true
                    }
                }
            }
            .store(in: &cancellables)

        appState.$budgetByEvent
            .map { [eventId] in $0[eventId] ?? 0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] budget in
                guard let self = self else { return }
                // Only update if different to avoid loops
                if self.plannedBudget != budget {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.plannedBudget = budget
                    }
                }
            }
            .store(in: &cancellables)
    }

    var totalSpent: Double {
        expenses.filter { $0.paymentStatus == .paid }.reduce(0) { $0 + $1.amount }
    }

    var totalPlanned: Double {
        expenses.filter { $0.paymentStatus == .pending }.reduce(0) { $0 + $1.amount }
    }

    var remaining: Double {
        max(plannedBudget - totalSpent - totalPlanned, 0)
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    func loadExpenses() async {
        // Use AppState to load (which handles caching)
        if let appState = appState {
            await appState.loadExpenses(for: eventId)
            // Sync local state with AppState cache BEFORE hiding shimmer
            let cachedExpenses = appState.expenses(for: eventId)
            let cachedBudget = appState.budget(for: eventId)
            if expenses != cachedExpenses || plannedBudget != cachedBudget {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expenses = cachedExpenses
                    plannedBudget = cachedBudget
                }
            }
        } else {
            // Fallback: load directly without AppState
            do {
                let freshExpenses = try await expenseRepository.getExpensesForEvent(eventId: eventId)
                var freshBudget: Double = 0
                do {
                    let eventBudget = try await GRPCClientService.shared.getEventBudget(eventId: eventId)
                    freshBudget = eventBudget.plannedBudget
                } catch {
                    // Budget may not exist yet
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    expenses = freshExpenses
                    plannedBudget = freshBudget
                }
            } catch {
                // Load failed
            }
        }

        // Hide shimmer AFTER data is updated
        isLoading = false
        isInitialized = true
    }

    func toggleExpenseSelection(_ expenseId: String) {
        if selectedExpenses.contains(expenseId) {
            selectedExpenses.remove(expenseId)
        } else {
            selectedExpenses.insert(expenseId)
        }
    }

    func toggleExpenseStatus(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        let originalExpense = expenses[index]
        let newStatus: PaymentStatus = originalExpense.paymentStatus == .paid ? .pending : .paid

        // Optimistic UI update with animation
        var updatedExpense = expenses[index]
        updatedExpense.paymentStatus = newStatus
        if newStatus == .paid {
            updatedExpense.paidAmount = expense.amount
        } else {
            updatedExpense.paidAmount = 0
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            expenses[index] = updatedExpense
            appState?.updateExpense(updatedExpense, eventId: eventId)
        }

        Task {
            do {
                if newStatus == .paid {
                    // Mark as paid: Add payment for the full amount
                    let remainingAmount = expense.amount - expense.paidAmount
                    if remainingAmount > 0 {
                        let responseExpense = try await expenseRepository.addPayment(expenseId: expense.id, amount: remainingAmount)
                        // Update local state and AppState with response
                        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expenses[idx] = responseExpense
                                appState?.updateExpense(responseExpense, eventId: eventId)
                            }
                        }
                    }
                } else {
                    // Mark as unpaid: Remove payment
                    let responseExpense = try await expenseRepository.removePayment(expenseId: expense.id)
                    // Update local state and AppState with response
                    if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expenses[idx] = responseExpense
                            appState?.updateExpense(responseExpense, eventId: eventId)
                        }
                    }
                }
            } catch {
                // Rollback on failure
                if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expenses[idx] = originalExpense
                        appState?.updateExpense(originalExpense, eventId: eventId)
                    }
                }
            }
        }
    }

    func addExpense(_ expense: Expense) {
        Task {
            do {
                let expenseId = try await expenseRepository.createExpense(expense)
                // Create new expense with the returned ID
                var createdExpense = Expense(
                    id: expenseId,
                    eventId: expense.eventId,
                    title: expense.title,
                    description: expense.description,
                    category: expense.category,
                    amount: expense.amount,
                    paidAmount: expense.paidAmount,
                    currency: expense.currency,
                    paymentStatus: expense.paymentStatus,
                    vendorId: expense.vendorId,
                    vendorName: expense.vendorName,
                    dueDate: expense.dueDate,
                    paidDate: expense.paidDate,
                    receiptURL: expense.receiptURL,
                    notes: expense.notes,
                    createdBy: expense.createdBy,
                    createdAt: expense.createdAt,
                    updatedAt: expense.updatedAt
                )
                // If created as paid, add payment to persist status on backend
                if expense.paymentStatus == .paid && expense.amount > 0 {
                    let paidExpense = try await expenseRepository.addPayment(expenseId: expenseId, amount: expense.amount)
                    createdExpense = paidExpense
                }
                // Add to AppState immediately
                withAnimation(.easeInOut(duration: 0.2)) {
                    expenses.append(createdExpense)
                    appState?.addExpense(createdExpense, eventId: eventId)
                }
            } catch {
                // Add failed
            }
        }
    }

    func updateExpense(_ expense: Expense) {
        // Optimistic update
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            let originalExpense = expenses[index]
            withAnimation(.easeInOut(duration: 0.2)) {
                expenses[index] = expense
                appState?.updateExpense(expense, eventId: eventId)
            }

            Task {
                do {
                    try await expenseRepository.updateExpense(expense)
                } catch {
                    // Rollback on failure
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expenses[index] = originalExpense
                        appState?.updateExpense(originalExpense, eventId: eventId)
                    }
                }
            }
        }
    }

    func deleteExpense(_ expenseId: String) {
        // Optimistic delete
        if let index = expenses.firstIndex(where: { $0.id == expenseId }) {
            let deletedExpense = expenses[index]
            withAnimation(.easeInOut(duration: 0.2)) {
                expenses.remove(at: index)
                appState?.removeExpense(id: expenseId, eventId: eventId)
            }

            Task {
                do {
                    try await expenseRepository.deleteExpense(id: expenseId)
                } catch {
                    // Rollback on failure
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expenses.insert(deletedExpense, at: index)
                        appState?.addExpense(deletedExpense, eventId: eventId)
                    }
                }
            }
        }
    }

    func deleteSelectedExpenses() {
        let idsToDelete = selectedExpenses
        let expensesToDelete = expenses.filter { idsToDelete.contains($0.id) }

        // Optimistic delete
        withAnimation(.easeInOut(duration: 0.2)) {
            expenses.removeAll { idsToDelete.contains($0.id) }
            appState?.removeExpenses(ids: idsToDelete, eventId: eventId)
        }
        selectedExpenses.removeAll()
        isMultiSelectEnabled = false

        Task {
            for expenseId in idsToDelete {
                do {
                    try await expenseRepository.deleteExpense(id: expenseId)
                } catch {
                    // Rollback this expense on failure
                    if let expense = expensesToDelete.first(where: { $0.id == expenseId }) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expenses.append(expense)
                            appState?.addExpense(expense, eventId: eventId)
                        }
                    }
                }
            }
        }
    }

    func updateBudget(_ budget: Double) {
        // Optimistic UI update
        let originalBudget = plannedBudget
        plannedBudget = budget
        appState?.updateBudget(budget, eventId: eventId)

        Task {
            do {
                _ = try await GRPCClientService.shared.upsertEventBudget(
                    eventId: eventId,
                    plannedBudget: budget
                )
            } catch {
                // Rollback on failure
                plannedBudget = originalBudget
                appState?.updateBudget(originalBudget, eventId: eventId)
            }
        }
    }

    func deleteAllExpenses() {
        let allExpenses = expenses

        // Optimistic delete all
        withAnimation(.easeInOut(duration: 0.2)) {
            expenses.removeAll()
            appState?.clearExpenseCache(for: eventId)
        }

        Task {
            for expense in allExpenses {
                do {
                    try await expenseRepository.deleteExpense(id: expense.id)
                } catch {
                    // Rollback this expense on failure
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expenses.append(expense)
                        appState?.addExpense(expense, eventId: eventId)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ExpensesListView(eventId: "preview-event-id")
    }
}
