import SwiftUI

// MARK: - Topic Pills Theme (Dark Mode Support)
struct TopicPillsTheme {
    let colorScheme: ColorScheme

    // Accent
    var accent: Color { Color(hex: "8251EB") }

    // Pill background gradient - dark mode uses subtle purple tint
    var pillGradientStart: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }
    var pillGradientEnd: Color {
        colorScheme == .dark ? Color(hex: "2C2330") : Color(hex: "F8F5FF")
    }

    // Pill border - more visible in dark mode
    var pillBorder: Color {
        colorScheme == .dark ? Color(hex: "8251EB").opacity(0.4) : Color(hex: "E5DBFF")
    }
}

// MARK: - Topic Pills Container
/// Horizontally scrolling topic pills matching Figma node 3103:43678
struct AITopicPillsView: View {
    let onTopicSelected: (AITopicType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { // 8px gap per Figma
                ForEach(AITopicType.allCases) { topic in
                    TopicPill(topic: topic, onTap: { onTopicSelected(topic) })
                }
            }
            .padding(.horizontal, 16) // Left padding per Figma (pl-[15.996px])
        }
        .padding(.horizontal, -16) // Offset parent padding to extend full width
    }
}

// MARK: - Single Topic Pill
/// Gradient pill button matching Figma design exactly
struct TopicPill: View {
    let topic: AITopicType
    let onTap: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    private var theme: TopicPillsTheme { TopicPillsTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: onTap) {
            Text(topic.rawValue)
                .font(.system(size: 15, weight: .medium))
                .tracking(-0.23)
                .foregroundColor(theme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    // Gradient from white to light purple (adaptive for dark mode)
                    LinearGradient(
                        colors: [theme.pillGradientStart, theme.pillGradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.pillBorder, lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    VStack {
        AITopicPillsView(onTopicSelected: { _ in })
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
