import SwiftUI

// MARK: - Checklist Theme (Dark Mode Support)
/// Adaptive colors for AI Checklist components
struct ChecklistTheme {
    let colorScheme: ColorScheme

    // Backgrounds - dark mode uses elevated surface color
    var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    // Text
    var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "0D1017").opacity(0.6)
    }

    // Divider
    var divider: Color {
        colorScheme == .dark ? Color(hex: "38383A") : Color(hex: "F3F4F6")
    }

    // Checkbox - more visible in dark mode
    var checkboxBorder: Color {
        colorScheme == .dark ? Color(hex: "636366") : Color(hex: "D1D5DC")
    }

    // Accent (stays consistent)
    var accent: Color { Color(hex: "8251EB") }
}

/// Type of action for checklist items based on topic
enum ChecklistActionType {
    case tasks
    case agenda
    case expenses

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .agenda: return "calendar.badge.plus"
        case .expenses: return "dollarsign.circle"
        }
    }

    var label: String {
        switch self {
        case .tasks: return "Tasks"
        case .agenda: return "Agenda"
        case .expenses: return "Budget"
        }
    }

    var successMessage: String {
        switch self {
        case .tasks: return "Added to your tasks!"
        case .agenda: return "Added to your agenda!"
        case .expenses: return "Added to your budget!"
        }
    }

    /// Determine action type from checklist topic
    static func from(topic: AITopicType?) -> ChecklistActionType {
        guard let topic = topic else { return .tasks }
        switch topic {
        case .timeline:
            return .agenda
        case .budget:
            return .expenses
        default:
            return .tasks
        }
    }
}

// MARK: - AI Checklist Card
/// Card displaying a checklist response from the AI - matching Figma design exactly
struct AIChecklistCard: View {
    let checklist: AIChatChecklist
    let onToggleItem: (String) -> Void
    let onSave: () -> Void
    let isSaved: Bool
    var onAddItems: (() -> Void)? = nil  // Optional callback to add unchecked items
    var itemsAdded: Bool = false  // Whether items have been added
    var actionType: ChecklistActionType = .tasks  // What type of items to add
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChecklistTheme { ChecklistTheme(colorScheme: colorScheme) }

    private var completedCount: Int {
        checklist.items.filter { $0.isChecked }.count
    }

    private var uncheckedCount: Int {
        checklist.items.filter { !$0.isChecked }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress header
            HStack {
                Text("Progress")
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.08)
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text("\(completedCount) of \(checklist.items.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundColor(theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Divider
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.6)
                .padding(.horizontal, 16)

            // Checklist items
            VStack(alignment: .leading, spacing: 0) {
                ForEach(checklist.items) { item in
                    ChecklistItemRow(
                        item: item,
                        onToggle: { onToggleItem(item.id) }
                    )
                }
            }
            .padding(.vertical, 4)

            // Add items button - only show if callback provided and not yet added
            if let onAddItems = onAddItems {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 0.6)
                    .padding(.horizontal, 16)

                if itemsAdded {
                    // Success message
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "22C55E"))
                        Text(actionType.successMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "22C55E"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                } else if uncheckedCount > 0 {
                    Button(action: onAddItems) {
                        HStack(spacing: 8) {
                            Image(systemName: actionType.icon)
                                .font(.system(size: 16))
                            Text("Add \(uncheckedCount) item\(uncheckedCount == 1 ? "" : "s") to \(actionType.label)")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }

            // Save button
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.6)
                .padding(.horizontal, 16)

            Button(action: onSave) {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                    Text(isSaved ? "Saved" : "Save")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(isSaved ? theme.accent : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .background(theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            // Border for dark mode visibility
            RoundedRectangle(cornerRadius: 20)
                .stroke(colorScheme == .dark ? Color(hex: "38383A") : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.1), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Checklist Item Row
struct ChecklistItemRow: View {
    let item: AIChatChecklistItem
    let onToggle: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChecklistTheme { ChecklistTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox - 24px with 8px rounded corners, 1.85px border
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            item.isChecked ? theme.accent : theme.checkboxBorder,
                            lineWidth: 1.85
                        )
                        .frame(width: 24, height: 24)

                    if item.isChecked {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.accent)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Text - 15px SF Pro regular
                Text(item.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: item.isChecked)
    }
}

// MARK: - Save Button
struct AISaveButton: View {
    let isSaved: Bool
    let onSave: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChecklistTheme { ChecklistTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: onSave) {
            HStack(spacing: 4) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 12))

                Text("Save")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSaved ? theme.accent : theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            AIChecklistCard(
                checklist: AIChatChecklist(
                    title: "Catering Checklist",
                    items: [
                        AIChatChecklistItem(text: "Determine the format (buffet, banquet, cocktail)", isChecked: false),
                        AIChatChecklistItem(text: "Consider guests' dietary restrictions", isChecked: false),
                        AIChatChecklistItem(text: "Plan a tasting 2-4 weeks in advance", isChecked: false),
                        AIChatChecklistItem(text: "Agree on the menu and drinks", isChecked: false),
                        AIChatChecklistItem(text: "Clarify if utensils and service are included", isChecked: false)
                    ]
                ),
                onToggleItem: { _ in },
                onSave: {},
                isSaved: false
            )
            .padding(.horizontal, 16)

            AISaveButton(isSaved: false, onSave: {})
        }
    }
    .background(Color(.systemGroupedBackground))
}
