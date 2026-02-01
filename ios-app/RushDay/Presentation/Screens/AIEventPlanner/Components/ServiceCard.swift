import SwiftUI

// MARK: - Service Card (Grid Style - for alternate layouts)

struct ServiceCard: View {
    let service: ServiceType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var iconBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color(hex: "8251EB") : iconBackgroundColor)
                        .frame(width: 52, height: 52)

                    Image(service.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? .white : textSecondaryColor)
                }

                // Title and subtitle
                VStack(spacing: 2) {
                    Text(service.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimaryColor)
                        .lineLimit(1)

                    Text(service.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(cardBackgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: "8251EB") : cardBorderColor,
                        lineWidth: isSelected ? 2 : 0.6
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "8251EB").opacity(0.15) : Color.clear,
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Services Grid

struct ServicesGrid: View {
    @Binding var selectedServices: Set<ServiceType>
    @Environment(\.colorScheme) private var colorScheme

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ServiceType.allCases) { service in
                ServiceCard(
                    service: service,
                    isSelected: selectedServices.contains(service),
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedServices.contains(service) {
                                selectedServices.remove(service)
                            } else {
                                selectedServices.insert(service)
                            }
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Service Card") {
    HStack(spacing: 12) {
        ServiceCard(service: .catering, isSelected: true, action: {})
        ServiceCard(service: .decoration, isSelected: false, action: {})
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Services Grid") {
    struct PreviewWrapper: View {
        @State private var selected: Set<ServiceType> = [.catering, .photoVideo]

        var body: some View {
            ScrollView {
                ServicesGrid(selectedServices: $selected)
                    .padding(24)
            }
            .background(Color(hex: "F8F9FC"))
        }
    }

    return PreviewWrapper()
}
