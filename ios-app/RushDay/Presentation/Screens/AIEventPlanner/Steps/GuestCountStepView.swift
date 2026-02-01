import SwiftUI

// MARK: - Guest Count Step View

struct GuestCountStepView: View {
    @Binding var selectedRange: GuestCountRange?
    @Binding var customCount: Int?
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @State private var showCustomInput = false
    @State private var customCountText = ""
    @State private var isVisible = false
    @FocusState private var isCustomInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dark Mode Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var customButtonTextColor: Color {
        colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "364153")
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color(hex: "6366F1") : Color(hex: "A393E8")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var placeholderColor: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "6A7282")
    }

    private var canProceed: Bool {
        if let count = Int(customCountText), count > 0 {
            return true
        }
        return false
    }

    /// Dynamic AI tip message based on selected guest count range
    private var aiTipMessage: String {
        guard let range = selectedRange else {
            return "Choose a guest count to help us find the perfect venue and calculate your budget!"
        }

        switch range {
        case .intimate:
            return "For intimate gatherings of 1-10 guests, consider a cozy restaurant or private room for a personal touch!"
        case .small:
            return "For 10-25 guests, a private dining room or small venue works great for close connections!"
        case .medium:
            return "For 25-50 guests, consider venues with flexible seating arrangements for the perfect balance!"
        case .large:
            return "For 50-100 guests, I recommend considering outdoor venues. They create a special atmosphere!"
        case .massive:
            return "For 100+ guests, look for large banquet halls or outdoor spaces with professional catering support!"
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Back button
                    if let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Back")
                                    .font(.system(size: 17, weight: .regular))
                                    .tracking(-0.41)
                            }
                            .foregroundColor(textSecondaryColor)
                        }
                        .opacity(isVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)
                    }

                    // AI Avatar - no animation, appears immediately
                    AIAvatarView(size: .small)

                    // Header text (left-aligned) - slides from LEFT
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How many guests are you expecting?")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(textPrimaryColor)
                            .tracking(0.4)

                        Text("This helps us find the right venue and calculate the budget")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.44)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                    // Guest count options - slides from LEFT
                    VStack(spacing: 12) {
                        ForEach(GuestCountRange.allCases) { range in
                            GuestCountOptionCard(
                                range: range,
                                isSelected: selectedRange == range,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedRange = range
                                        customCount = nil
                                        customCountText = ""
                                        showCustomInput = false
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
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                    // Custom input button OR inline input - slides from LEFT
                    Group {
                        if showCustomInput {
                            // Inline custom guest count input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Specify exact number of guests")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(customButtonTextColor)

                                HStack(spacing: 12) {
                                    TextField("e.g., 45", text: $customCountText)
                                        .font(.system(size: 16))
                                        .foregroundColor(textPrimaryColor)
                                        .keyboardType(.numberPad)
                                        .focused($isCustomInputFocused)
                                        .onChange(of: customCountText) { _, newValue in
                                            // Filter to only digits
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                customCountText = filtered
                                            }
                                            if let count = Int(filtered), count > 0 {
                                                customCount = count
                                            } else {
                                                customCount = nil
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(inputBackgroundColor)
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(inputBorderColor, lineWidth: 0.6)
                                        )

                                    Button(action: {
                                        if canProceed {
                                            selectedRange = nil
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
                            // "Enter exact guest count" button
                            Button(action: {
                                selectedRange = nil
                                showCustomInput = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isCustomInputFocused = true
                                    withAnimation {
                                        proxy.scrollTo("customInput", anchor: .center)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image("guests_custom_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "8251EB"))

                                    Text("Enter exact guest count")
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
                        }
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: isVisible)

                    // AI Tip - slides from LEFT (dynamic based on selection)
                    AITipCard(
                        message: aiTipMessage,
                        style: .blue
                    )
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: isVisible)

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

// MARK: - Custom Guest Count Input Sheet

struct CustomGuestCountInputSheet: View {
    @Binding var customCount: Int?
    @Binding var customCountText: String
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @FocusState private var isFocused: Bool

    private var canProceed: Bool {
        customCount != nil && customCount! > 0
    }

    private var disabledButtonColor: Color {
        colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DB")
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Enter Guest Count")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            // Text field with inline Next button
            HStack(spacing: 12) {
                Image("guests_custom_icon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(hex: "8251EB"))

                TextField("e.g., 75 guests", text: $customCountText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .onChange(of: customCountText) { _, newValue in
                        if let count = Int(newValue), count > 0 {
                            customCount = count
                        } else {
                            customCount = nil
                        }
                    }

                // Inline Next button
                Button(action: {
                    if canProceed {
                        onNext()
                    }
                }) {
                    Text("Next")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            canProceed
                                ? Color(hex: "8251EB")
                                : disabledButtonColor
                        )
                        .cornerRadius(8)
                }
                .disabled(!canProceed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )

            Spacer()
        }
        .padding(24)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview

#Preview("Guest Count Step") {
    struct PreviewWrapper: View {
        @State private var selectedRange: GuestCountRange? = nil
        @State private var customCount: Int? = nil

        var body: some View {
            GuestCountStepView(
                selectedRange: $selectedRange,
                customCount: $customCount,
                onContinue: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
