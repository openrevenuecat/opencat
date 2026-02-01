import SwiftUI

// MARK: - Budget Step View

struct BudgetStepView: View {
    @Binding var selectedTier: BudgetTier?
    @Binding var customAmount: Int?
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @State private var showCustomInput = false
    @State private var customAmountText = ""
    @State private var isVisible = false
    @FocusState private var isCustomInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "D1D5DC")
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color(hex: "6366F1") : Color(hex: "A393E8")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var canProceed: Bool {
        if let amount = Int(customAmountText), amount > 0 {
            return true
        }
        return false
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Back button
                if let onBack = onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .regular))
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundColor(textSecondaryColor)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)
                }

                // AI Avatar - no animation
                AIAvatarView(size: .small)

                // Header text (left-aligned)
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's your budget?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineSpacing(6)
                        .tracking(0.4)

                    Text("This helps us find services within your budget")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .lineSpacing(6)
                        .tracking(-0.44)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                // Budget tier options - auto-advance on selection
                VStack(spacing: 16) {
                    ForEach(BudgetTier.allCases) { tier in
                        BudgetOptionCard(
                            tier: tier,
                            isSelected: selectedTier == tier && customAmount == nil,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTier = tier
                                    customAmount = nil
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                // Auto-advance after short delay for visual feedback
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onContinue()
                                }
                            }
                        )
                    }

                    // Custom budget input - inline or button
                    Group {
                        if showCustomInput {
                            // Inline custom budget input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Enter budget amount")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(textSecondaryColor)

                                HStack(spacing: 12) {
                                    Text("$")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(Color(hex: "8251EB"))

                                    TextField("0", text: $customAmountText)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(textPrimaryColor)
                                        .keyboardType(.numberPad)
                                        .focused($isCustomInputFocused)
                                        .onChange(of: customAmountText) { _, newValue in
                                            // Filter to only digits
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                customAmountText = filtered
                                            }
                                            if let amount = Int(filtered), amount > 0 {
                                                customAmount = amount
                                            } else {
                                                customAmount = nil
                                            }
                                        }
                                        .frame(maxWidth: .infinity)

                                    Button(action: {
                                        if canProceed {
                                            selectedTier = nil
                                            onContinue()
                                        }
                                    }) {
                                        Text("Next")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: canProceed
                                                        ? [Color(hex: "8251EB"), Color(hex: "6366F1")]
                                                        : [Color(hex: "8251EB").opacity(0.5), Color(hex: "6366F1").opacity(0.5)]
                                                    ),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .cornerRadius(14)
                                    }
                                    .disabled(!canProceed)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(inputBackgroundColor)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(inputBorderColor, lineWidth: 0.6)
                                )
                            }
                            .padding(24)
                            .background(cardBackgroundColor)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(cardBorderColor, lineWidth: 0.6)
                            )
                            .id("customInput")
                        } else {
                            // "Enter exact budget amount" button
                            Button(action: {
                                selectedTier = nil
                                showCustomInput = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isCustomInputFocused = true
                                    withAnimation {
                                        proxy.scrollTo("customInput", anchor: .center)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image("custom_budget_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "8251EB"))

                                    Text("Enter exact budget amount")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(textPrimaryColor)
                                        .tracking(-0.31)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(cardBackgroundColor)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(cardBorderColor, lineWidth: 0.6)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                // AI Tip - Orange style for budget step - slides from RIGHT
                AITipCard(
                    message: "I'll find options within your budget and suggest where you can save without compromising quality.",
                    style: .orange
                )
                .opacity(isVisible ? 1 : 0)
                .offset(x: isVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.45), value: isVisible)

                Spacer()
                    .frame(height: 300) // Extra space for keyboard
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .scrollBounceHaptic()
        .onAppear {
            isVisible = true
        }
        .onChange(of: isCustomInputFocused) { _, isFocused in
            if isFocused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        proxy.scrollTo("customInput", anchor: .center)
                    }
                }
            }
        }
    }
    }
}

// MARK: - Budget Option Card

private struct BudgetOptionCard: View {
    let tier: BudgetTier
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
            HStack(spacing: 20) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: tier.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(tier.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(tier.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimaryColor)
                            .tracking(-0.45)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(tier.range)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.15)
                            .lineLimit(1)
                    }

                    Text(tier.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Checkmark when selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "8251EB"))
                }
            }
            .padding(24)
            .frame(height: 104)
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

// MARK: - Preview

#Preview("Budget Step") {
    struct PreviewWrapper: View {
        @State private var selectedTier: BudgetTier? = nil
        @State private var customAmount: Int? = nil

        var body: some View {
            BudgetStepView(
                selectedTier: $selectedTier,
                customAmount: $customAmount,
                onContinue: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
