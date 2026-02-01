import SwiftUI

// MARK: - AI Tip Card

struct AITipCard: View {
    let message: String
    var style: AITipStyle = .purple

    @Environment(\.colorScheme) private var colorScheme

    private var messageTextColor: Color {
        colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "364153")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? style.iconColor.opacity(0.15) : style.backgroundColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon with circular background
            ZStack {
                Circle()
                    .fill(style.iconBackgroundColor)
                    .frame(width: 32, height: 32)

                Image(style.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(style.iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Label
                Text("AI Tip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(style.titleColor)
                    .tracking(-0.15)

                // Message
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(messageTextColor)
                    .lineSpacing(2)
                    .tracking(-0.15)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style.borderColor, lineWidth: 0.6)
        )
    }
}

// MARK: - Preview

#Preview("AI Tip Card") {
    VStack(spacing: 16) {
        AITipCard(
            message: "The event type helps me suggest the perfect vendors and create a tailored experience.",
            style: .purple
        )

        AITipCard(
            message: "The venue type affects catering, decoration, and overall event logistics.",
            style: .blue
        )

        AITipCard(
            message: "If you haven't decided on a venue yet, you can skip this step. AI will suggest options later.",
            style: .green
        )

        AITipCard(
            message: "I'll find options within your budget and suggest where you can save without compromising quality.",
            style: .orange
        )
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}
