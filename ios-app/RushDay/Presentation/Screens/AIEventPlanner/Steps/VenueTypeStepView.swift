import SwiftUI

// MARK: - Venue Type Step View

struct VenueTypeStepView: View {
    @Binding var selectedVenueType: AIVenueType?
    @Binding var customVenueName: String
    let onContinue: () -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    @State private var showCustomInput = false
    @State private var isVisible = false
    @FocusState private var isCustomInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : .rdTextPrimary
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : .rdTextSecondary
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color(hex: "6366F1") : Color(hex: "A393E8")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var canProceed: Bool {
        !customVenueName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Back and Skip buttons
                HStack {
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
                    }

                    Spacer()

                    // Skip button - pill style matching other steps
                    Button(action: onSkip) {
                        HStack(spacing: 8) {
                            Text("Skip")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .tracking(-0.15)

                            Image("skip_arrow_icon")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "6B7280"))
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 12)
                        .frame(height: 37)
                        .background(
                            colorScheme == .dark
                                ? Color(hex: "374151").opacity(0.8)
                                : Color.white.opacity(0.8)
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "E5E7EB"),
                                    lineWidth: 0.6
                                )
                        )
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)

                // AI Avatar - no animation
                AIAvatarView(size: .small)

                // Header text (left-aligned)
                VStack(alignment: .leading, spacing: 12) {
                    Text("What type of venue\ninterests you?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineSpacing(6)
                        .tracking(0.4)

                    Text("Choose a venue type or skip this step")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .lineSpacing(6)
                        .tracking(-0.44)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                // Venue type options - auto-advance on selection
                VStack(spacing: 12) {
                    ForEach(AIVenueType.allCases) { venue in
                        VenueTypeOptionCard(
                            venueType: venue,
                            isSelected: selectedVenueType == venue,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedVenueType = venue
                                    customVenueName = "" // Clear custom venue when selecting type
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

                    // Custom venue name input - inline or button
                    Group {
                        if showCustomInput {
                            // Inline custom venue input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Enter venue name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(textSecondaryColor)

                                HStack(spacing: 12) {
                                    Image("location_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "8251EB"))

                                    TextField("e.g., Central Park, Grand Hotel...", text: $customVenueName)
                                        .font(.system(size: 16))
                                        .foregroundColor(textPrimaryColor)
                                        .focused($isCustomInputFocused)
                                        .frame(maxWidth: .infinity)

                                    Button(action: {
                                        if canProceed {
                                            selectedVenueType = nil
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
                            // "Enter specific venue name" button
                            Button(action: {
                                selectedVenueType = nil
                                showCustomInput = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isCustomInputFocused = true
                                    withAnimation {
                                        proxy.scrollTo("customInput", anchor: .center)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image("location_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "8251EB"))

                                    Text("Enter specific venue name")
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

                // AI Tip - Green style for venue step - slides from RIGHT
                AITipCard(
                    message: "If you haven't decided on a venue yet, you can skip this step. AI will suggest options later.",
                    style: .green
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

// MARK: - Preview

#Preview("Venue Type Step") {
    struct PreviewWrapper: View {
        @State private var selectedVenue: AIVenueType? = nil
        @State private var customVenueName: String = ""

        var body: some View {
            VenueTypeStepView(
                selectedVenueType: $selectedVenue,
                customVenueName: $customVenueName,
                onContinue: {},
                onSkip: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}

#Preview("Venue Type Step - Dark Mode") {
    struct PreviewWrapper: View {
        @State private var selectedVenue: AIVenueType? = nil
        @State private var customVenueName: String = ""

        var body: some View {
            VenueTypeStepView(
                selectedVenueType: $selectedVenue,
                customVenueName: $customVenueName,
                onContinue: {},
                onSkip: {}
            )
            .background(WizardBackground())
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
