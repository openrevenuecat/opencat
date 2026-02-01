import SwiftUI

// MARK: - Option Card (List Style)

struct OptionCard<T: Identifiable>: View {
    let title: String
    let subtitle: String
    let badge: String?
    let icon: String
    let gradientColors: [Color]
    let isSelected: Bool
    let showCheckmark: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String,
        badge: String? = nil,
        icon: String,
        gradientColors: [Color],
        isSelected: Bool,
        showCheckmark: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.icon = icon
        self.gradientColors = gradientColors
        self.isSelected = isSelected
        self.showCheckmark = showCheckmark
        self.action = action
    }

    // MARK: - Dark Mode Colors

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var badgeBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var badgeTextColor: Color {
        colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "6B7280")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(textPrimaryColor)
                            .tracking(-0.44)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(badgeTextColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(badgeBackgroundColor)
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator (optional)
                if showCheckmark && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "8251EB"))
                }
            }
            .padding(20)
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
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Guest Count Option Card

struct GuestCountOptionCard: View {
    let range: GuestCountRange
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with gradient background - using custom image (48x48 per Figma)
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: range.gradientColors),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(range.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 0) {
                    Text(range.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimaryColor)
                        .tracking(-0.44)

                    Text(range.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(20)
            .frame(height: 89) // Match Figma 89px height
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
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Venue Type Option Card

struct VenueTypeOptionCard: View {
    let venueType: AIVenueType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with gradient background - using custom image (56x56 per Figma)
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: venueType.gradientColors),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(venueType.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(venueType.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimaryColor)
                        .tracking(-0.44)

                    Text(venueType.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
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

// MARK: - Budget Tier Option Card

struct BudgetTierOptionCard: View {
    let tier: BudgetTier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        OptionCard<BudgetTier>(
            title: tier.title,
            subtitle: tier.subtitle,
            badge: tier.range,
            icon: tier.icon,
            gradientColors: tier.gradientColors,
            isSelected: isSelected,
            action: action
        )
    }
}

// MARK: - Custom Input Card

struct CustomInputCard: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var iconBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var iconColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Text field
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(textColor)
                .keyboardType(keyboardType)

            Spacer()
        }
        .padding(16)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Guest Count Options") {
    VStack(spacing: 12) {
        ForEach(GuestCountRange.allCases) { range in
            GuestCountOptionCard(
                range: range,
                isSelected: range == .medium,
                action: {}
            )
        }
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Venue Type Options") {
    VStack(spacing: 12) {
        ForEach(AIVenueType.allCases) { venue in
            VenueTypeOptionCard(
                venueType: venue,
                isSelected: venue == .indoorVenue,
                action: {}
            )
        }
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Budget Tier Options") {
    VStack(spacing: 12) {
        ForEach(BudgetTier.allCases) { tier in
            BudgetTierOptionCard(
                tier: tier,
                isSelected: tier == .standard,
                action: {}
            )
        }
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Custom Input Card") {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack(spacing: 12) {
                CustomInputCard(
                    placeholder: "Enter custom amount",
                    icon: "dollarsign.circle",
                    text: $text,
                    keyboardType: .numberPad
                )
            }
            .padding(24)
            .background(Color(hex: "F8F9FC"))
        }
    }

    return PreviewWrapper()
}
