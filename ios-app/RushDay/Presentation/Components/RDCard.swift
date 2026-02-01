import SwiftUI

struct RDCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.rdSurface)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Event Card (Large with cover image)
struct EventCard: View {
    let event: Event
    var onTap: (() -> Void)?
    var height: CGFloat = 400

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack(alignment: .bottom) {
                // Cover Image Background
                CachedAsyncImage(url: URL(string: event.effectiveCoverImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    // Fallback gradient
                    LinearGradient(
                        colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(height: height)
                .clipped()

                // Blurred copy of the image for bottom overlay
                CachedAsyncImage(url: URL(string: event.effectiveCoverImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                        .blur(radius: 20)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
                .frame(height: height)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.55),
                            .init(color: .black, location: 0.75),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Text content on top
                VStack(alignment: .leading, spacing: 12) {
                    // Event Name
                    Text(event.name)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.38)
                        .lineHeight(34)
                        .lineLimit(2)

                    // Date and Venue
                    EventCardInfo(event: event)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Card Compact (without cover image)
struct EventCardCompact: View {
    let event: Event
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Event Name
                Text(event.name)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Date and Venue
                EventCardInfo(event: event)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                BlurredOverlay()
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Card Info (shared component)
struct EventCardInfo: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("calendar_icon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(hex: "F2F2F7"))

                Text(event.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "F2F2F7"))
                    .tracking(-0.23)
            }

            if let venue = event.venue {
                HStack(alignment: .top, spacing: 8) {
                    Image("location_icon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(hex: "F2F2F7"))

                    Text(venue)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "F2F2F7"))
                        .tracking(-0.23)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Blurred Overlay
struct BlurredOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.4),
                Color.black.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 0.5)
    }
}

// MARK: - Blur Effect View
struct BlurEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Selection Card
struct SelectionCard: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var iconColor: Color = .rdAccent
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                        .frame(width: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodyLarge)
                        .foregroundColor(.rdTextPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.captionMedium)
                            .foregroundColor(.rdTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .rdAccent : .rdTextTertiary)
            }
            .padding(16)
            .background(Color.rdSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.rdAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.captionLarge)
                .foregroundColor(.rdTextTertiary)
                .tracking(0.5)

            Spacer()

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.labelMedium)
                        .foregroundColor(.rdAccent)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            EventCard(event: .mock)

            SelectionCard(
                title: "Birthday Party",
                subtitle: "Celebrate someone special",
                icon: "birthday.cake.fill",
                iconColor: .birthday,
                isSelected: true,
                action: {}
            )

            SelectionCard(
                title: "Wedding",
                icon: "heart.fill",
                iconColor: .wedding,
                isSelected: false,
                action: {}
            )

            SectionHeader(title: "Upcoming Events", action: {}, actionTitle: "See All")

            RDCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Card Content")
                        .font(.headlineSmall)
                    Text("This is a flexible card component")
                        .font(.bodyMedium)
                        .foregroundColor(.rdTextSecondary)
                }
            }
        }
        .padding()
    }
    .background(Color.rdBackground)
}
