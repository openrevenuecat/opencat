import SwiftUI

// MARK: - Preferences Step View (Step 7)

struct PreferencesStepView: View {
    @Binding var preferencesText: String
    @Binding var selectedTags: Set<String>
    let onGenerate: () -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    @FocusState private var isTextFieldFocused: Bool
    @State private var isVisible = false
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

    private var placeholderColor: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "6A7282")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
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

                        // Skip button - pill style
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

                    // Header text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Any additional\npreferences?")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(textPrimaryColor)
                            .lineSpacing(6)
                            .tracking(0.4)

                        Text("Tell us about your style preferences or special requirements")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.44)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                    // Text input area
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $preferencesText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 128, maxHeight: 128)
                                .padding(12)
                                .background(cardBackgroundColor)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(cardBorderColor, lineWidth: 0.6)
                                )
                                .focused($isTextFieldFocused)

                            if preferencesText.isEmpty {
                                Text("e.g., I want a relaxed atmosphere, no formalities,\nwith live music...")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(placeholderColor)
                                    .tracking(-0.31)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }

                        // Character counter
                        Text("\(preferencesText.count) characters")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.15)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                    // Quick ideas section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick ideas by category:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(textSecondaryColor)
                            .tracking(-0.15)

                        // Categories with more spacing between them
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(QuickIdeaCategory.allCategories) { category in
                                QuickIdeaCategoryView(
                                    category: category,
                                    selectedTags: $selectedTags,
                                    onTagSelected: { tag in
                                        appendTagToPreferences(tag)
                                    }
                                )
                            }
                        }
                    }
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: isVisible)

                    // AI Tip - slides from RIGHT
                    AITipCard(
                        message: "AI will analyze your answers and generate personalized event plans in ~30 seconds",
                        style: .purple
                    )
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : 30)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: isVisible)

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollBounceHaptic()
            .onAppear {
                isVisible = true
            }
            .onTapGesture {
                isTextFieldFocused = false
            }

            // Sticky Generate button
            VStack(spacing: 0) {
                // Selected ideas count
                if !selectedTags.isEmpty {
                    Text("\(selectedTags.count) \(selectedTags.count == 1 ? "idea" : "ideas") selected")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }

                Button(action: onGenerate) {
                    HStack(spacing: 8) {
                        Text("Generate Event Plans")
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(-0.44)

                        Image("sparkle_icon")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
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
                    .cornerRadius(16)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, selectedTags.isEmpty ? 16 : 12)
                .padding(.bottom, 16)
            }
            .background(
                (colorScheme == .dark ? Color(hex: "1F2937") : Color.white)
                    .opacity(0.8)
            )
        }
    }

    private func appendTagToPreferences(_ tag: String) {
        if preferencesText.isEmpty {
            preferencesText = tag
        } else if !preferencesText.contains(tag) {
            preferencesText += ", \(tag)"
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Quick Idea Category View

private struct QuickIdeaCategoryView: View {
    let category: QuickIdeaCategory
    @Binding var selectedTags: Set<String>
    let onTagSelected: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header with icon
            HStack(spacing: 8) {
                Image(category.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(category.color)

                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                    .tracking(-0.15)
            }

            // Tags flow layout
            FlowLayout(spacing: 8) {
                ForEach(category.tags, id: \.self) { tag in
                    QuickIdeaTagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                                onTagSelected(tag)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Quick Idea Tag Button

private struct QuickIdeaTagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        if isSelected {
            return Color.clear // No border when gradient is shown
        }
        return colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "E5E7EB")
    }

    private var textColor: Color {
        if isSelected {
            return .white // White text when selected
        }
        return colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "364153")
    }

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textColor)
                .tracking(-0.15)
                .padding(.horizontal, 16)
                .frame(height: 37)
                .background(
                    Group {
                        if isSelected {
                            // Gradient background when selected (top to bottom per Figma)
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "8251EB"),
                                    Color(hex: "6366F1")
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            colorScheme == .dark
                                ? Color(hex: "374151").opacity(0.8)
                                : Color.white.opacity(0.8)
                        }
                    }
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: isSelected ? 0 : 0.6)
                )
                .shadow(
                    color: isSelected ? Color(hex: "8251EB").opacity(0.3) : Color.clear,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview("Preferences Step") {
    struct PreviewWrapper: View {
        @State private var preferencesText = ""
        @State private var selectedTags: Set<String> = []

        var body: some View {
            PreferencesStepView(
                preferencesText: $preferencesText,
                selectedTags: $selectedTags,
                onGenerate: {},
                onSkip: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}

#Preview("Preferences Step - Dark") {
    struct PreviewWrapper: View {
        @State private var preferencesText = "I want a relaxed vibe with live music"
        @State private var selectedTags: Set<String> = ["Relaxed vibe", "Live music band"]

        var body: some View {
            PreferencesStepView(
                preferencesText: $preferencesText,
                selectedTags: $selectedTags,
                onGenerate: {},
                onSkip: {}
            )
            .background(WizardBackground())
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
