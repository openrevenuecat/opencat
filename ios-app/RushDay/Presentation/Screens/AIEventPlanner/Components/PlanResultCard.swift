import SwiftUI

// MARK: - Plan Result Card

struct PlanResultCard: View {
    let plan: GeneratedPlan
    let onSeePlan: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.95) : Color.white
    }

    private var detailIconColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var costBoxBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2D2640") : Color(hex: "F3F0FF")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with badge and match score
            headerSection

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Title and style tag
                titleSection

                // Description
                Text(plan.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .tracking(-0.15)

                // Details section (Venue, Catering, Entertainment)
                detailsSection

                // Total cost and See Plan button
                footerSection
            }
            .padding(16)
        }
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: 16,
            x: 0,
            y: 8
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Badge (if applicable)
            if let badgeText = plan.tier.badgeText {
                HStack(spacing: 6) {
                    if let badgeIcon = plan.tier.badgeIcon {
                        Image(badgeIcon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }

                    Text(badgeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.12)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: plan.tier.badgeColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }

            Spacer()

            // Match score - white pill with black text (matching Figma)
            Text("\(plan.matchScore)% match")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(textPrimaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    colorScheme == .dark
                        ? Color(hex: "374151").opacity(0.9)
                        : Color.white.opacity(0.9)
                )
                .cornerRadius(20)
        }
        .padding(16)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main title (e.g., "Classic Celebration")
            Text(plan.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textPrimaryColor)
                .tracking(0.07)

            // Style subtitle in purple (e.g., "Elegant Classic")
            Text(plan.style.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "8251EB"))
                .tracking(-0.15)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let venue = plan.venueDescription {
                detailRow(icon: "venue_detail_icon", fallbackIcon: "mappin.circle.fill", label: "Venue", text: venue)
            }

            if let catering = plan.cateringDescription {
                detailRow(icon: "catering_detail_icon", fallbackIcon: "fork.knife", label: "Catering", text: catering)
            }

            if let entertainment = plan.entertainmentDescription {
                detailRow(icon: "entertainment_detail_icon", fallbackIcon: "music.note", label: "Entertainment", text: entertainment)
            }
        }
    }

    private func detailRow(icon: String, fallbackIcon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            Group {
                if UIImage(named: icon) != nil {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: fallbackIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 16, height: 16)
            .foregroundColor(detailIconColor)

            // Label and description
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(detailIconColor)

                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.15)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Total cost badge
            HStack(spacing: 4) {
                Text("Total:")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(-0.15)

                Text("$\(plan.estimatedCost)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: plan.style.gradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)

            Spacer()

            // See Plan button
            Button(action: onSeePlan) {
                HStack(spacing: 8) {
                    Text("See Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.32)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "8251EB"),
                            Color(hex: "6366F1")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Compact Plan Result Card (for horizontal scroll if needed)

struct CompactPlanResultCard: View {
    let plan: GeneratedPlan
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with badge and match score
                HStack {
                    if let badgeText = plan.tier.badgeText {
                        Text(badgeText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: plan.tier.badgeColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text("\(plan.matchScore)% match")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color(hex: "374151").opacity(0.9)
                                : Color.white.opacity(0.9)
                        )
                        .cornerRadius(12)
                }

                // Title and style
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineLimit(1)

                    Text(plan.style.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "8251EB"))
                }

                // Price
                Text("$\(plan.estimatedCost)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(plan.style.gradientColors.first ?? .purple)

                // Description
                Text(plan.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .padding(16)
            .frame(width: 200)
            .background(colorScheme == .dark ? Color(hex: "1F2937") : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: "8251EB") : (colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "8251EB").opacity(0.15) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Plan Summary Card (for results - uses full GeneratedPlan with tasks)

struct PlanSummaryCard: View {
    let plan: GeneratedPlan
    let isLoading: Bool
    let onSeePlan: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.95) : Color.white
    }

    private var detailIconColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var costBoxBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2D2640") : Color(hex: "F3F0FF")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with badge and match score
            headerSection

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Title and style tag
                titleSection

                // Description
                Text(plan.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .tracking(-0.15)

                // Details section (Venue, Catering, Entertainment) - matches Figma design
                detailsSection

                // Total cost and See Plan button
                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            colorScheme == .dark
                ? Color(hex: "1F2937").opacity(0.8)
                : Color.white.opacity(0.8)
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB"),
                    lineWidth: 0.6
                )
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Badge (if applicable)
            if let badgeText = plan.tier.badgeText {
                HStack(spacing: 4) {
                    if let badgeIcon = plan.tier.badgeIcon {
                        Image(badgeIcon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }

                    Text(badgeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: plan.tier.badgeColors),
                        startPoint: plan.tier == .popular ? .leading : .top,
                        endPoint: plan.tier == .popular ? .trailing : .bottom
                    )
                )
                .cornerRadius(20)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 4
                )
            }

            Spacer()

            // Match score - white pill with black text (matching Figma)
            Text("\(plan.matchScore)% match")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(textPrimaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    colorScheme == .dark
                        ? Color(hex: "374151").opacity(0.9)
                        : Color.white.opacity(0.9)
                )
                .cornerRadius(20)
        }
        .padding(16)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main title (e.g., "Classic Celebration")
            Text(plan.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textPrimaryColor)
                .tracking(0.07)

            // Style subtitle in purple (e.g., "Elegant Classic")
            Text(plan.style.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "8251EB"))
                .tracking(-0.15)
        }
    }

    // MARK: - Details Section (Venue, Catering, Entertainment - Figma design)

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let venue = plan.venueDescription {
                detailRow(icon: "venue_detail_icon", fallbackIcon: "mappin.circle.fill", label: "Venue", text: venue)
            }

            if let catering = plan.cateringDescription {
                detailRow(icon: "catering_detail_icon", fallbackIcon: "fork.knife", label: "Catering", text: catering)
            }

            if let entertainment = plan.entertainmentDescription {
                detailRow(icon: "entertainment_detail_icon", fallbackIcon: "music.note", label: "Entertainment", text: entertainment)
            }

            // Fallback to highlights if no descriptions available
            if plan.venueDescription == nil && plan.cateringDescription == nil && plan.entertainmentDescription == nil {
                highlightsFallbackSection
            }
        }
    }

    private func detailRow(icon: String, fallbackIcon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            Group {
                if UIImage(named: icon) != nil {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: fallbackIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 16, height: 16)
            .foregroundColor(detailIconColor)

            // Label and description
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(detailIconColor)
                    .tracking(-0.12)

                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.15)
                    .lineLimit(2)
            }
        }
    }

    // Fallback: Show highlights if venue/catering/entertainment not available
    private var highlightsFallbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(plan.highlights.prefix(3), id: \.self) { highlight in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "10B981"))

                    Text(highlight)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Total cost box with gradient border (matching Figma)
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Cost")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(textSecondaryColor)

                Text(formatTotalCost())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimaryColor)
                    .tracking(0.07)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "8251EB").opacity(0.1),
                        Color(hex: "6366F1").opacity(0.1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color(hex: "8251EB").opacity(0.2),
                        lineWidth: 0.6
                    )
            )

            // See Plan button - full width
            RDGradientButton(
                "See Plan",
                isLoading: isLoading,
                cornerRadius: 14,
                action: onSeePlan
            )
        }
    }

    private func formatTotalCost() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: plan.totalCost)) ?? "$\(plan.totalCost)"
    }
}

// MARK: - Compact Plan Summary Card (for horizontal scroll)

struct CompactPlanSummaryCard: View {
    let plan: GeneratedPlan
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with badge and match score
                HStack {
                    if let badgeText = plan.tier.badgeText {
                        Text(badgeText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: plan.tier.badgeColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text("\(plan.matchScore)% match")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color(hex: "374151").opacity(0.9)
                                : Color.white.opacity(0.9)
                        )
                        .cornerRadius(12)
                }

                // Title and style
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineLimit(1)

                    Text(plan.style.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "8251EB"))
                }

                // Budget range
                Text(formatBudgetRange())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(plan.style.gradientColors.first ?? .purple)

                // Description
                Text(plan.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .padding(16)
            .frame(width: 200)
            .background(colorScheme == .dark ? Color(hex: "1F2937") : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: "8251EB") : (colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "8251EB").opacity(0.15) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func formatBudgetRange() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        let min = formatter.string(from: NSNumber(value: plan.estimatedBudgetMin)) ?? "$\(plan.estimatedBudgetMin)"
        let max = formatter.string(from: NSNumber(value: plan.estimatedBudgetMax)) ?? "$\(plan.estimatedBudgetMax)"

        return "\(min)-\(max)"
    }
}

// MARK: - Preview

#Preview("Plan Result Card") {
    ScrollView {
        VStack(spacing: 24) {
            PlanResultCard(plan: .mockClassic, onSeePlan: {})
            PlanResultCard(plan: .mockModern, onSeePlan: {})
            PlanResultCard(plan: .mockNatural, onSeePlan: {})
        }
        .padding(24)
    }
    .background(Color(hex: "F8F9FC"))
}

#Preview("Plan Result Card - Dark") {
    ScrollView {
        VStack(spacing: 24) {
            PlanResultCard(plan: .mockClassic, onSeePlan: {})
            PlanResultCard(plan: .mockModern, onSeePlan: {})
        }
        .padding(24)
    }
    .background(Color(hex: "111827"))
    .preferredColorScheme(.dark)
}

#Preview("Compact Plan Cards") {
    struct PreviewWrapper: View {
        @State private var selected: String? = "classic-1"

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(GeneratedPlan.mockPlans) { plan in
                        CompactPlanResultCard(
                            plan: plan,
                            isSelected: selected == plan.id,
                            onSelect: { selected = plan.id }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(hex: "F8F9FC"))
        }
    }

    return PreviewWrapper()
}
