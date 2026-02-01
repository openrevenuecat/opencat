import SwiftUI

// MARK: - Chat Message Bubble
struct AIChatBubble: View {
    let message: AIChatMessage
    let onToggleChecklistItem: (String) -> Void
    let onSave: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var userBubbleColor: Color {
        Color(hex: "8251EB")
    }

    private var aiBubbleColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var userTextColor: Color {
        .white
    }

    private var aiTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "1F2937")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar (small)
                AIMiniAvatar()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message content or checklist
                if let checklist = message.checklist {
                    AIChecklistCard(
                        checklist: checklist,
                        onToggleItem: onToggleChecklistItem,
                        onSave: onSave,
                        isSaved: message.isSaved
                    )
                    .frame(maxWidth: 300)
                } else {
                    // Regular text message
                    Text(message.content)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(message.isUser ? userTextColor : aiTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? userBubbleColor : aiBubbleColor)
                        .cornerRadius(18)
                        .cornerRadius(message.isUser ? 18 : 4, corners: message.isUser ? [.bottomRight] : [.topLeft])
                }
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Mini AI Avatar
struct AIMiniAvatar: View {
    private let size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "8251EB"), Color(hex: "A78BFA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Two white bars
            HStack(spacing: 4) {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 4, height: 8)

                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 4, height: 8)
            }
        }
    }
}

// MARK: - AI Typing Indicator
struct AITypingIndicator: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    @Environment(\.colorScheme) private var colorScheme

    private var dotColor: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9CA3AF")
    }

    private var bubbleBackground: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI Avatar
            AIMiniAvatar()

            // Typing bubble
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffsets[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .cornerRadius(18)
            .cornerRadius(4, corners: [.topLeft])

            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotOffsets[i] = -6
            }
        }
    }
}

// MARK: - Preview
#Preview("Chat Bubbles") {
    VStack(spacing: 16) {
        AIChatBubble(
            message: AIChatMessage(
                content: "Can you help me with catering options for my birthday party?",
                isUser: true
            ),
            onToggleChecklistItem: { _ in },
            onSave: {}
        )

        AIChatBubble(
            message: AIChatMessage(
                content: "Of course! I'd love to help you plan the catering for your birthday party. Here are some key questions to consider:",
                isUser: false
            ),
            onToggleChecklistItem: { _ in },
            onSave: {}
        )

        AITypingIndicator()
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
