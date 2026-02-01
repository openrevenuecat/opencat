import SwiftUI

// MARK: - Event Type Step View

struct EventTypeStepView: View {
    @Binding var selectedEventType: AIEventType?
    @Binding var customEventType: String
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @State private var isVisible = false
    @State private var showCustomInput = false
    @FocusState private var isCustomInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

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
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "D1D5DC")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color(hex: "6366F1") : Color(hex: "A393E8")
    }

    private var disabledButtonColor: Color {
        colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DB")
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
                            Text("Cancel")
                                .font(.system(size: 17, weight: .regular))
                                .tracking(-0.41)
                        }
                        .foregroundColor(textPrimaryColor)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)
                }

                // AI Avatar - no animation
                AIAvatarView(size: .small)

                // Header text (left-aligned) - slides from LEFT
                VStack(alignment: .leading, spacing: 12) {
                    Text("What event are\nyou planning?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineSpacing(6)
                        .tracking(0.4)

                    Text("Choose the type of event to get the best recommendations")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .lineSpacing(6)
                        .tracking(-0.44)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(x: isVisible ? 0 : -30)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                // Event type grid - slides from LEFT
                EventTypeGrid(selectedType: $selectedEventType)
                    .onChange(of: selectedEventType) { _, newValue in
                        if let eventType = newValue {
                            if eventType == .other {
                                // Show custom input and focus keyboard for "Other"
                                showCustomInput = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isCustomInputFocused = true
                                    withAnimation {
                                        proxy.scrollTo("customInput", anchor: .center)
                                    }
                                }
                            } else {
                                // Auto-advance for other event types
                                customEventType = ""
                                showCustomInput = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onContinue()
                                }
                            }
                        }
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                // "Enter custom event type" button OR inline input
                Group {
                    if showCustomInput {
                        // Inline custom event type input - matches Figma design
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Specify your event type")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "364153"))
                                .tracking(-0.31)

                            HStack(spacing: 12) {
                                // Text field with purple border
                                TextField("e.g., Corporate retreat, Product launch...", text: $customEventType)
                                    .font(.system(size: 16))
                                    .foregroundColor(textPrimaryColor)
                                    .focused($isCustomInputFocused)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(height: 49)
                                    .background(inputBackgroundColor)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(hex: "9D89E9"), lineWidth: 0.6)
                                    )

                                // Next button with gradient
                                Button(action: {
                                    if !customEventType.trimmingCharacters(in: .whitespaces).isEmpty {
                                        selectedEventType = nil
                                        onContinue()
                                    }
                                }) {
                                    Text("Next")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .tracking(-0.31)
                                        .frame(width: 82, height: 49)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(hex: "8251EB"), Color(hex: "6366F1")]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(customEventType.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                                        .cornerRadius(14)
                                }
                                .disabled(customEventType.trimmingCharacters(in: .whitespaces).isEmpty)
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
                        // "Enter custom event type" button
                        Button(action: {
                            selectedEventType = .other
                            showCustomInput = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isCustomInputFocused = true
                                withAnimation {
                                    proxy.scrollTo("customInput", anchor: .center)
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "8251EB"))

                                Text("Enter custom event type")
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

                // AI Tip - slides from LEFT
                AITipCard(
                    message: "Not sure what to choose? Select \"Other\" and describe your event in your own words on the following steps",
                    style: .purple
                )
                .opacity(isVisible ? 1 : 0)
                .offset(x: isVisible ? 0 : -30)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: isVisible)

                Spacer()
                    .frame(height: 300) // Extra space for keyboard
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
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
}

// MARK: - Step Header

struct StepHeader: View {
    var avatar: Bool = false
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }

    var body: some View {
        VStack(spacing: 16) {
            if avatar {
                AIAvatarView(size: .small)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textPrimaryColor)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview("Event Type Step") {
    struct PreviewWrapper: View {
        @State private var selectedType: AIEventType? = nil
        @State private var customType = ""

        var body: some View {
            EventTypeStepView(
                selectedEventType: $selectedType,
                customEventType: $customType,
                onContinue: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}
