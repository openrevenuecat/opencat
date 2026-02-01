import SwiftUI

// MARK: - Generating Step View

struct GeneratingStepView: View {
    @Binding var currentStep: GenerationStep
    @Binding var progress: CGFloat
    @Binding var isComplete: Bool

    // Request data for "Your Request" section
    var eventType: String = "Birthday Party"
    var guestCount: String = "25-50"
    var budget: String = "Premium"

    @State private var justCompletedStep: GenerationStep?
    @State private var previousStep: GenerationStep?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var textTertiaryColor: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "6A7282")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 24)

                // Loading avatar with pulsing rings
                GeneratingAvatarView()

                Spacer()
                    .frame(height: 48)

                // Title - must be ONE LINE
                Text("Creating Perfect Plans...")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(textPrimaryColor)
                    .tracking(0.4)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()
                    .frame(height: 16)

                // Subtitle
                Text("This will only take a few seconds")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .tracking(-0.44)
                    .lineLimit(1)

                Spacer()
                    .frame(height: 48)

                // Progress bar with label
                progressBar

                Spacer()
                    .frame(height: 32)

                // Progress steps
                VStack(spacing: 16) {
                    ForEach(GenerationStep.allCases, id: \.rawValue) { step in
                        GenerationProgressCard(
                            step: step,
                            stepState: stepState(for: step)
                        )
                    }
                }

                Spacer()
                    .frame(height: 32)

                // Your Request section
                yourRequestSection

                Spacer()
                    .frame(height: 100)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            previousStep = currentStep
        }
        .onChange(of: currentStep) { oldValue, newValue in
            // Mark the previous step as "just completed" with animation
            if newValue.rawValue > oldValue.rawValue {
                justCompletedStep = oldValue

                // Clear "just completed" after animation finishes (no animation wrapper)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    justCompletedStep = nil
                }
            }
            previousStep = newValue
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB"))
                        .frame(height: 8)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "8251EB"),
                                    Color(hex: "A78BFA"),
                                    Color(hex: "6366F1")
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)

            // Progress label and percentage
            HStack {
                Text("Progress")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textTertiaryColor)
                    .tracking(-0.15)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "8251EB"))
                    .tracking(-0.15)
            }
        }
    }

    // MARK: - Your Request Section

    private var yourRequestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Request:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.31)

            VStack(alignment: .leading, spacing: 8) {
                requestRow(label: "Type:", value: eventType.capitalized)
                requestRow(label: "Guests:", value: guestCount)
                requestRow(label: "Budget:", value: budget.capitalized)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 0.6)
        )
    }

    private func requestRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            // Purple bullet point
            Text("•")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "8251EB"))

            // Label
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textSecondaryColor)
                .tracking(-0.15)

            // Value
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textPrimaryColor)
                .tracking(-0.15)
        }
    }

    // MARK: - Helpers

    private func stepState(for step: GenerationStep) -> GenerationProgressCard.StepState {
        if isComplete {
            return .completed
        }

        // Check if this step was just completed (transition animation)
        if step == justCompletedStep {
            return .justCompleted
        }

        if step.rawValue < currentStep.rawValue {
            return .completed
        } else if step.rawValue == currentStep.rawValue {
            return .inProgress
        } else {
            return .pending
        }
    }
}

// MARK: - Generating Avatar View (with pulsing rings and sparkle icon)

struct GeneratingAvatarView: View {
    @State private var iconRotation: Double = 0
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring3Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.5
    @State private var ring2Opacity: Double = 0.4
    @State private var ring3Opacity: Double = 0.2

    private let avatarSize: CGFloat = 128

    private let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    var body: some View {
        ZStack {
            // Ring 3 (outermost)
            Circle()
                .stroke(Color(hex: "8251EB").opacity(0.3), lineWidth: 1.85)
                .frame(width: avatarSize + 60, height: avatarSize + 60)
                .scaleEffect(ring3Scale)
                .opacity(ring3Opacity)

            // Ring 2 (middle)
            Circle()
                .stroke(Color(hex: "8251EB").opacity(0.3), lineWidth: 1.85)
                .frame(width: avatarSize + 24, height: avatarSize + 24)
                .scaleEffect(ring2Scale)
                .opacity(ring2Opacity)

            // Ring 1 (inner)
            Circle()
                .stroke(Color(hex: "8251EB").opacity(0.3), lineWidth: 1.85)
                .frame(width: avatarSize + 2, height: avatarSize + 2)
                .scaleEffect(ring1Scale)
                .opacity(ring1Opacity)

            // Main avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: avatarSize, height: avatarSize)
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 25,
                    x: 0,
                    y: 25
                )

            // Sparkle icon (rotating)
            Image("sparkle_icon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .foregroundColor(.white)
                .rotationEffect(.degrees(iconRotation))
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Icon rotation
        withAnimation(
            Animation
                .linear(duration: 8.0)
                .repeatForever(autoreverses: false)
        ) {
            iconRotation = 360
        }

        // Ring pulsing animations with staggered timing
        withAnimation(
            Animation
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            ring1Scale = 1.05
            ring1Opacity = 0.6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(
                Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                ring2Scale = 1.08
                ring2Opacity = 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(
                Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                ring3Scale = 1.1
                ring3Opacity = 0.3
            }
        }
    }
}

// MARK: - Generation Progress Card

struct GenerationProgressCard: View {
    enum StepState {
        case pending
        case inProgress
        case justCompleted // Transition state with rotation animation
        case completed
    }

    let step: GenerationStep
    let stepState: StepState

    @Environment(\.colorScheme) private var colorScheme
    @State private var iconRotation: Double = 0
    @State private var showCheckmark: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Status icon circle - 40px per Figma
            ZStack {
                Circle()
                    .fill(circleBackgroundColor)
                    .frame(width: 40, height: 40)

                if stepState == .justCompleted {
                    // Animated transition: icon rotates and transforms to checkmark
                    ZStack {
                        // Step icon (fades out while rotating)
                        Image(step.icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .opacity(showCheckmark ? 0 : 1)

                        // Checkmark (fades in while rotating)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .opacity(showCheckmark ? 1 : 0)
                    }
                    .onAppear {
                        // Start the rotation animation
                        withAnimation(.easeInOut(duration: 0.5)) {
                            iconRotation = 360
                        }
                        // Switch icon midway through rotation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showCheckmark = true
                            }
                        }
                    }
                } else if stepState == .completed {
                    // Static checkmark for already completed
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    // Step icon - 20px per Figma
                    Image(step.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(iconColor)
                }
            }

            // Step title - 16px medium per Figma
            Text(step.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
                .tracking(-0.31)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            // Animated dots for in-progress
            if stepState == .inProgress {
                AnimatedLoadingDots()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 73) // 73px per Figma
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 0.6)
        )
    }

    private var cardBackground: some View {
        Group {
            switch stepState {
            case .completed, .justCompleted:
                Color(hex: "8251EB").opacity(0.1)
            case .inProgress:
                colorScheme == .dark ? Color(hex: "1F2937") : Color.white
            case .pending:
                colorScheme == .dark
                    ? Color(hex: "1F2937").opacity(0.5)
                    : Color.white.opacity(0.5)
            }
        }
    }

    private var borderColor: Color {
        switch stepState {
        case .completed, .justCompleted:
            return Color(hex: "8251EB").opacity(0.3)
        case .inProgress:
            return colorScheme == .dark ? Color(hex: "374151") : Color(hex: "D1D5DC")
        case .pending:
            return colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
        }
    }

    private var circleBackgroundColor: Color {
        switch stepState {
        case .completed, .justCompleted:
            return Color(hex: "8251EB")
        case .inProgress:
            return colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
        case .pending:
            return colorScheme == .dark ? Color(hex: "374151").opacity(0.5) : Color(hex: "F3F4F6")
        }
    }

    private var iconColor: Color {
        switch stepState {
        case .completed, .justCompleted:
            return .white
        case .inProgress:
            return colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
        case .pending:
            return colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9CA3AF")
        }
    }

    private var textColor: Color {
        switch stepState {
        case .completed, .justCompleted, .inProgress:
            return colorScheme == .dark ? .white : Color(hex: "101828")
        case .pending:
            return colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "6A7282")
        }
    }
}

// MARK: - Animated Loading Dots

private struct AnimatedLoadingDots: View {
    @State private var dot1Scale: CGFloat = 1.0
    @State private var dot2Scale: CGFloat = 0.85
    @State private var dot3Scale: CGFloat = 0.7

    @State private var dot1Opacity: Double = 0.9
    @State private var dot2Opacity: Double = 0.76
    @State private var dot3Opacity: Double = 0.5

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color(hex: "8251EB"))
                .frame(width: 9, height: 9)
                .scaleEffect(dot1Scale)
                .opacity(dot1Opacity)

            Circle()
                .fill(Color(hex: "8251EB"))
                .frame(width: 9, height: 9)
                .scaleEffect(dot2Scale)
                .opacity(dot2Opacity)

            Circle()
                .fill(Color(hex: "8251EB"))
                .frame(width: 9, height: 9)
                .scaleEffect(dot3Scale)
                .opacity(dot3Opacity)
        }
        .frame(width: 35, height: 9) // Fixed frame to prevent layout shifts
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Animate dots in sequence
        withAnimation(
            Animation
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
        ) {
            dot1Scale = 0.7
            dot1Opacity = 0.5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                dot2Scale = 0.7
                dot2Opacity = 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                dot3Scale = 1.0
                dot3Opacity = 0.9
            }
        }
    }
}

// MARK: - Preview

#Preview("Generating Step") {
    struct PreviewWrapper: View {
        @State private var currentStep: GenerationStep = .creatingProgram
        @State private var progress: CGFloat = 0.5
        @State private var isComplete = false

        var body: some View {
            GeneratingStepView(
                currentStep: $currentStep,
                progress: $progress,
                isComplete: $isComplete,
                eventType: "business",
                guestCount: "25-50",
                budget: "premium"
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}

#Preview("Generating Step - Dark") {
    struct PreviewWrapper: View {
        @State private var currentStep: GenerationStep = .calculatingBudget
        @State private var progress: CGFloat = 0.7
        @State private var isComplete = false

        var body: some View {
            GeneratingStepView(
                currentStep: $currentStep,
                progress: $progress,
                isComplete: $isComplete,
                eventType: "Wedding",
                guestCount: "50-100",
                budget: "Premium"
            )
            .background(WizardBackground())
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}

#Preview("Generating Step - Complete") {
    struct PreviewWrapper: View {
        @State private var currentStep: GenerationStep = .generatingPlans
        @State private var progress: CGFloat = 1.0
        @State private var isComplete = true

        var body: some View {
            GeneratingStepView(
                currentStep: $currentStep,
                progress: $progress,
                isComplete: $isComplete
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
