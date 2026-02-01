import SwiftUI

// MARK: - Event Type Card (Grid Style)

struct EventTypeCard: View {
    let eventType: AIEventType
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: eventType.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    Image(eventType.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white)
                }

                // Title (left-aligned)
                Text(eventType.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(cardBackgroundColor)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isSelected ? Color(hex: "8251EB") : cardBorderColor,
                        lineWidth: isSelected ? 2 : 0.6
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "8251EB").opacity(0.15) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Event Type Grid

struct EventTypeGrid: View {
    @Binding var selectedType: AIEventType?
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(AIEventType.allCases) { eventType in
                EventTypeCard(
                    eventType: eventType,
                    isSelected: selectedType == eventType,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = eventType
                        }
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Event Type Card") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            EventTypeCard(eventType: .birthday, isSelected: true, action: {})
            EventTypeCard(eventType: .wedding, isSelected: false, action: {})
        }

        HStack(spacing: 12) {
            EventTypeCard(eventType: .business, isSelected: false, action: {})
            EventTypeCard(eventType: .babyShower, isSelected: false, action: {})
        }
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Event Type Grid") {
    struct PreviewWrapper: View {
        @State private var selected: AIEventType? = .birthday

        var body: some View {
            ScrollView {
                EventTypeGrid(selectedType: $selected)
                    .padding(24)
            }
            .background(Color(hex: "F8F9FC"))
        }
    }

    return PreviewWrapper()
}
