import SwiftUI

// MARK: - Budget Summary Card
/// Reusable budget summary card component matching Figma design
/// Design reference: Figma node 301:38314
struct BudgetSummaryCard: View {
    let rows: [BudgetSummaryRow]
    let totalRow: BudgetTotalRow?

    init(rows: [BudgetSummaryRow], totalRow: BudgetTotalRow? = nil) {
        self.rows = rows
        self.totalRow = totalRow
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                BudgetSummaryRowView(row: row)

                if index < rows.count - 1 || totalRow != nil {
                    Divider()
                        .background(Color(hex: "181818").opacity(0.24))
                        .padding(.leading, 16)
                }
            }

            if let total = totalRow {
                BudgetTotalRowView(row: total)
            }
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Budget Summary Row Model
struct BudgetSummaryRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    let onTap: (() -> Void)?

    init(icon: String, title: String, value: String, valueColor: Color = .rdPrimary, onTap: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.onTap = onTap
    }
}

// MARK: - Budget Total Row Model
struct BudgetTotalRow {
    let title: String
    let value: String
    let valueColor: Color

    init(title: String, value: String, valueColor: Color = .rdWarning) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
}

// MARK: - Budget Summary Row View
private struct BudgetSummaryRowView: View {
    let row: BudgetSummaryRow

    var body: some View {
        Button {
            row.onTap?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: row.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.rdPrimary)
                    .frame(width: 24, height: 24)

                Text(row.title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
                    .tracking(-0.44)

                Spacer()

                Text(row.value)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(row.valueColor)
                    .tracking(-0.44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(row.onTap == nil)
    }
}

// MARK: - Budget Total Row View
private struct BudgetTotalRowView: View {
    let row: BudgetTotalRow

    var body: some View {
        HStack(spacing: 8) {
            Text(row.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)
                .tracking(-0.44)

            Spacer()

            Text(row.value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(row.valueColor)
                .tracking(-0.44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        BudgetSummaryCard(
            rows: [
                BudgetSummaryRow(icon: "banknote", title: "Budget", value: "2000$"),
                BudgetSummaryRow(icon: "list.clipboard", title: "Planned", value: "0$"),
                BudgetSummaryRow(icon: "wallet.pass", title: "Remaining", value: "2000$")
            ],
            totalRow: BudgetTotalRow(title: "Total Expenses", value: "0$", valueColor: .rdWarning)
        )
        .padding(16)
    }
    .background(Color.rdBackground)
}
