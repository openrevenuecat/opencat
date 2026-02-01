import SwiftUI

// MARK: - AI Event Chat Button (Entry Point)
/// Floating AI avatar button matching Figma design exactly - node 3103:44275
struct AIEventChatButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            // Reuse AIAvatarView component - small size (64px)
            AIAvatarView(size: .small, isAnimating: true)
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                AIEventChatButton(action: {})
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
    }
}
