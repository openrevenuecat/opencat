import SwiftUI

// MARK: - Results Step View

struct ResultsStepView: View {
    // Full plans with tasks (no separate fetch needed)
    let plans: [GeneratedPlan]
    @Binding var selectedPlan: GeneratedPlan?
    let isLoading: Bool

    // Wizard step values for "Want to change parameters?" section
    let eventTypeValue: String?
    let guestCountValue: String?
    let venueValue: String?
    let budgetValue: String?

    // Callbacks
    let onSelectPlan: (GeneratedPlan) -> Void
    let onCreateEvent: () -> Void
    let onGenerateMore: (String) -> Void  // Accepts adjustment text
    var onBack: (() -> Void)?
    var onChangeParameter: ((ParameterType) -> Void)?

    @State private var adjustmentText: String = ""
    @FocusState private var isAdjustmentFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Parameter Types for "Want to change parameters?"

    enum ParameterType: String, CaseIterable {
        case eventType = "Event Type"
        case guestCount = "Guest Count"
        case venue = "Venue"
        case budget = "Budget"
        case services = "Services"
        case preferences = "Preferences"

        var icon: String {
            switch self {
            case .eventType: return "party.popper"
            case .guestCount: return "person.2"
            case .venue: return "mappin.circle"
            case .budget: return "dollarsign.circle"
            case .services: return "square.grid.2x2"
            case .preferences: return "slider.horizontal.3"
            }
        }
    }

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151").opacity(0.5) : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back and regenerate buttons
            headerSection

            // Main content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // AI Avatar and title
                    titleSection

                    // Adjustment input
                    adjustmentInputSection

                    // Plan cards
                    plansSection

                    // Want to change parameters?
                    changeParametersSection

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollBounceHaptic()
            .onTapGesture {
                isAdjustmentFocused = false
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back button
            if let onBack = onBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .regular))
                        Text("Back")
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.41)
                    }
                    .foregroundColor(textPrimaryColor)
                }
            }

            Spacer()

            // Regenerate button (no X/close button)
            Button(action: { onGenerateMore("") }) {
                HStack(spacing: 8) {
                    Image("regenerate_icon")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)

                    Text("Regenerate")
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.31)
                }
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "364153"))
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .background(cardBackgroundColor)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorderColor, lineWidth: 0.6)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI Avatar
            AIAvatarView(size: .small)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 12) {
                Text("I prepared plans for you!")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(textPrimaryColor)
                    .lineSpacing(6)
                    .tracking(0.4)

                Text("Choose your favorite option or compare several")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .lineSpacing(6)
                    .tracking(-0.44)
            }
        }
    }

    // MARK: - Adjustment Input Section

    private var adjustmentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            HStack(spacing: 6) {
                Image("sparkle_adjustment_icon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color(hex: "8251EB"))

                Text("Additional preferences for adjustment")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "364153"))
                    .tracking(-0.31)
            }

            // Input field with Apply button
            HStack(spacing: 12) {
                TextField("e.g., I want more live music or less flowers...", text: $adjustmentText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.31)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(inputBackgroundColor)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isAdjustmentFocused ? Color(hex: "8251EB") : cardBorderColor,
                                lineWidth: isAdjustmentFocused ? 1.5 : 0.6
                            )
                    )
                    .focused($isAdjustmentFocused)

                // Apply button
                Button(action: {
                    // Apply adjustment - pass the text to ViewModel
                    isAdjustmentFocused = false
                    if !adjustmentText.isEmpty {
                        onGenerateMore(adjustmentText)
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Apply")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(-0.31)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "8251EB").opacity(adjustmentText.isEmpty ? 0.5 : 1.0))
                    .cornerRadius(14)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(adjustmentText.isEmpty)
            }
        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 0.6)
        )
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        VStack(spacing: 20) {
            ForEach(plans) { plan in
                PlanSummaryCard(
                    plan: plan,
                    isLoading: isLoading && selectedPlan?.id == plan.id,
                    onSeePlan: {
                        onSelectPlan(plan)
                    }
                )
            }
        }
    }

    // MARK: - Change Parameters Section

    private var changeParametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image("change_parameters_icon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(hex: "8251EB"))

                Text("Want to change parameters?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.31)
            }

            // Parameter chips - dynamic flow layout
            FlowLayout(spacing: 8) {
                parameterChipWithValue(label: "Event Type:", value: eventTypeValue ?? "Not set")
                parameterChipWithValue(label: "Guest Count:", value: guestCountValue ?? "Not set")
                parameterChipWithValue(label: "Venue:", value: venueValue ?? "Not set")
                parameterChipWithValue(label: "Budget:", value: budgetValue ?? "Not set")
            }
        }
        .padding(24)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 0.6)
        )
    }

    private func parameterChipWithValue(label: String, value: String) -> some View {
        Button(action: {
            // Determine which parameter this is
            let param: ParameterType? = {
                if label.contains("Event Type") { return .eventType }
                if label.contains("Guest") { return .guestCount }
                if label.contains("Venue") { return .venue }
                if label.contains("Budget") { return .budget }
                return nil
            }()
            if let param = param {
                onChangeParameter?(param)
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .tracking(-0.15)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimaryColor)
                    .tracking(-0.15)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .frame(height: 37)
            .background(
                colorScheme == .dark
                    ? Color(hex: "1F2937")
                    : Color.white
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorderColor, lineWidth: 0.6)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Horizontal Scroll Results View (Alternative)

struct HorizontalResultsView: View {
    let plans: [GeneratedPlan]
    @Binding var selectedPlan: GeneratedPlan?
    let onSelectPlan: (GeneratedPlan) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                AIAvatarView(size: .small)

                VStack(spacing: 8) {
                    Text("Choose Your Plan")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textPrimaryColor)

                    Text("Select the option that fits you best")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Horizontal scroll of plans
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(plans) { plan in
                        CompactPlanSummaryCard(
                            plan: plan,
                            isSelected: selectedPlan?.id == plan.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPlan = plan
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Selected plan details
            if let plan = selectedPlan {
                VStack(spacing: 16) {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(plan.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimaryColor)

                        Text(plan.description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .lineSpacing(4)

                        HStack(spacing: 8) {
                            ForEach(plan.highlights.prefix(3), id: \.self) { highlight in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "10B981"))

                                    Text(highlight)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "364153"))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Select plan button
                    Button(action: { onSelectPlan(plan) }) {
                        HStack(spacing: 8) {
                            Text("View Plan Details")
                                .font(.system(size: 18, weight: .semibold))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: plan.style.gradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .background(colorScheme == .dark ? Color(hex: "1F2937") : Color.white)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview

#Preview("Results Step") {
    ResultsStepView(
        plans: GeneratedPlan.mockPlans,
        selectedPlan: .constant(nil),
        isLoading: false,
        eventTypeValue: "Wedding",
        guestCountValue: "25-50",
        venueValue: "Outdoor Space",
        budgetValue: "Standard",
        onSelectPlan: { _ in },
        onCreateEvent: {},
        onGenerateMore: { _ in }
    )
    .background(WizardBackground())
}

#Preview("Results Step - Dark") {
    ResultsStepView(
        plans: GeneratedPlan.mockPlans,
        selectedPlan: .constant(nil),
        isLoading: false,
        eventTypeValue: "Birthday Party",
        guestCountValue: "10-25",
        venueValue: "Indoor Venue",
        budgetValue: "Premium",
        onSelectPlan: { _ in },
        onCreateEvent: {},
        onGenerateMore: { _ in }
    )
    .background(WizardBackground())
    .preferredColorScheme(.dark)
}

#Preview("Horizontal Results") {
    struct PreviewWrapper: View {
        @State private var selectedPlan: GeneratedPlan? = GeneratedPlan.mockPlans.first

        var body: some View {
            HorizontalResultsView(
                plans: GeneratedPlan.mockPlans,
                selectedPlan: $selectedPlan,
                onSelectPlan: { _ in }
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
