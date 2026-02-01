import SwiftUI

// MARK: - ConnectionLostBanner

/// A floating banner that displays when network connection is lost
/// Matches Figma design: node-id=2003:22543
struct ConnectionLostBanner: View {

    // MARK: - Properties

    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var isVisible = false

    // MARK: - Body

    var body: some View {
        VStack {
            if isVisible {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onReceive(networkMonitor.$isConnected) { isConnected in
            withAnimation {
                isVisible = !isConnected
            }
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        HStack(spacing: 13) {
            // Warning Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)

            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.connectionLostTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(L10n.connectionLostMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.6))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        ConnectionLostBanner()
    }
}
