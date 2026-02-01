import SwiftUI

// MARK: - Services Step View

struct ServicesStepView: View {
    @Binding var selectedServices: Set<ServiceType>
    @Binding var customService: String
    let onContinue: () -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    @State private var customServiceText = ""
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
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var iconBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color(hex: "6366F1") : Color(hex: "A393E8")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var canAddService: Bool {
        !customServiceText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
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

                    // Skip button - pill style matching Figma
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
                    Text("What services do you need?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(textPrimaryColor)
                        .lineSpacing(6)
                        .tracking(0.4)

                    Text("Select all that apply (you can choose multiple)")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.31)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: isVisible)

                // Services list
                VStack(spacing: 16) {
                    ForEach(ServiceType.allCases) { service in
                        ServiceOptionCard(
                            service: service,
                            isSelected: selectedServices.contains(service),
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedServices.contains(service) {
                                        selectedServices.remove(service)
                                    } else {
                                        selectedServices.insert(service)
                                    }
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                    }

                    // Custom service input section (always visible per Figma)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter custom service")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "D1D5DB") : Color(hex: "364153"))
                            .tracking(-0.31)

                        HStack(spacing: 12) {
                            TextField("e.g., Security service, Fireworks...", text: $customServiceText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .tracking(-0.31)
                                .focused($isCustomInputFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(height: 49)
                                .background(colorScheme == .dark ? Color(hex: "1F2937") : Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(cardBorderColor, lineWidth: 0.6)
                                )

                            Button(action: {
                                if canAddService {
                                    customService = customServiceText.trimmingCharacters(in: .whitespaces)
                                    customServiceText = ""
                                    isCustomInputFocused = false
                                }
                            }) {
                                Text("Add")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .tracking(-0.31)
                                    .frame(width: 78, height: 49)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "8251EB"), Color(hex: "6366F1")]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(canAddService ? 1.0 : 0.5)
                                    .cornerRadius(14)
                            }
                            .disabled(!canAddService)
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
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: isVisible)

                // Selected services count badge (above Continue button per Figma)
                if !selectedServices.isEmpty {
                    HStack {
                        Spacer()
                        Text("Selected services: ")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "8251EB"))
                            .tracking(-0.15)
                        +
                        Text("\(selectedServices.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "8251EB"))
                            .tracking(-0.15)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color(hex: "8251EB").opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "8251EB").opacity(0.2), lineWidth: 0.6)
                    )
                }

                // Continue button - scrolls with content
                if !selectedServices.isEmpty || !customService.isEmpty {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(-0.44)
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
                }

                // AI Tip - Green style for services step - slides from RIGHT
                AITipCard(
                    message: "Don't worry if you're unsure. I'll suggest optimal service combinations in the final plans",
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
    }
}

// MARK: - Service Option Card

private struct ServiceOptionCard: View {
    let service: ServiceType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    private var iconBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    private var checkboxBorderColor: Color {
        colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DC")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with background (gradient when selected, gray when not)
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "8251EB"), Color(hex: "6366F1")]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 48, height: 48)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(iconBackgroundColor)
                            .frame(width: 48, height: 48)
                    }

                    Image(service.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? .white : (colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "364153")))
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimaryColor)
                        .tracking(-0.44)
                        .lineLimit(1)

                    Text(service.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.15)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "8251EB") : checkboxBorderColor, lineWidth: isSelected ? 0 : 1.85)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color(hex: "8251EB"))
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .frame(height: 93)
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
                color: isSelected ? Color.black.opacity(0.1) : Color.clear,
                radius: isSelected ? 10 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview("Services Step") {
    struct PreviewWrapper: View {
        @State private var selectedServices: Set<ServiceType> = [.catering, .decoration]
        @State private var customService: String = ""

        var body: some View {
            ServicesStepView(
                selectedServices: $selectedServices,
                customService: $customService,
                onContinue: {},
                onSkip: {}
            )
            .background(WizardBackground())
        }
    }

    return PreviewWrapper()
}

#Preview("Services Step - Dark") {
    struct PreviewWrapper: View {
        @State private var selectedServices: Set<ServiceType> = [.entertainment]
        @State private var customService: String = ""

        var body: some View {
            ServicesStepView(
                selectedServices: $selectedServices,
                customService: $customService,
                onContinue: {},
                onSkip: {}
            )
            .background(WizardBackground())
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
