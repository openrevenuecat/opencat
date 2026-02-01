import SwiftUI

// MARK: - Wizard Progress Bar

struct WizardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    @Environment(\.colorScheme) private var colorScheme

    // Number of dots to show (last step doesn't get a dot)
    private var dotCount: Int {
        totalSteps - 1
    }

    private var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    private let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.95) : Color.white.opacity(0.9)
    }

    private var trackColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    var body: some View {
        VStack(spacing: 8) {
            // Step label and percentage
            HStack {
                Text("STEP \(currentStep + 1) OF \(totalSteps)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .tracking(0.6)

                Spacer()

                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "8251EB"))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(trackColor)
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)

            // Step dots (centered) - only show dotCount dots (last step has no dot)
            HStack(spacing: 6) {
                ForEach(0..<dotCount, id: \.self) { step in
                    stepDot(for: step)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.3))
                .frame(height: 0.33),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func stepDot(for step: Int) -> some View {
        if step == currentStep {
            // Current step - pill shape
            Capsule()
                .fill(Color(hex: "8251EB"))
                .frame(width: 24, height: 6)
        } else if step < currentStep {
            // Completed step - 50% opacity purple
            Circle()
                .fill(Color(hex: "8251EB").opacity(0.5))
                .frame(width: 6, height: 6)
        } else {
            // Pending step
            Circle()
                .fill(colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DC"))
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Compact Progress Bar (for step headers)

struct CompactProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    var showSkip: Bool = false
    var onSkip: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    private var trackColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress indicator
            VStack(alignment: .leading, spacing: 4) {
                Text("STEP \(currentStep + 1) OF \(totalSteps)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textSecondaryColor)
                    .tracking(0.5)

                // Mini progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(trackColor)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "8251EB"),
                                        Color(hex: "A78BFA")
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(width: 80, height: 4)
            }

            Spacer()

            // Skip button (optional)
            if showSkip, let onSkip = onSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondaryColor)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview("Wizard Progress Bar") {
    VStack(spacing: 40) {
        WizardProgressBar(currentStep: 0, totalSteps: 8)
        WizardProgressBar(currentStep: 1, totalSteps: 8)
        WizardProgressBar(currentStep: 3, totalSteps: 8)
        WizardProgressBar(currentStep: 7, totalSteps: 8)
    }
    .background(Color(hex: "F8F9FC"))
}

#Preview("Compact Progress Bar") {
    VStack(spacing: 20) {
        CompactProgressBar(currentStep: 0, totalSteps: 8)
        CompactProgressBar(currentStep: 2, totalSteps: 8, showSkip: true, onSkip: {})
        CompactProgressBar(currentStep: 5, totalSteps: 8, showSkip: true, onSkip: {})
    }
    .background(Color.white)
}
