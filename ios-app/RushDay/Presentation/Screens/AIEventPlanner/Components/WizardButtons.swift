import SwiftUI

// MARK: - Wizard Back Button

/// Back button for wizard navigation
struct WizardBackButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .regular))
                Text("Back")
                    .font(.system(size: 17, weight: .regular))
            }
            .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Wizard Skip Button

/// Skip button for optional wizard steps
struct WizardSkipButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Wizard Continue Button

/// Primary continue button for wizard steps
struct WizardContinueButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: String = "Continue",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WizardConstants.buttonHeight)
                .background(
                    Group {
                        if isEnabled {
                            LinearGradient(
                                colors: WizardConstants.primaryGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.gray.opacity(0.5)
                        }
                    }
                )
                .cornerRadius(WizardConstants.buttonCornerRadius)
        }
        .disabled(!isEnabled)
        .padding(.horizontal, WizardConstants.horizontalPadding)
    }
}

// MARK: - Wizard Generate Button

/// Outline button with AI icon for generate actions
struct WizardGenerateButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    init(
        _ title: String,
        icon: String = "sparkles",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.rdPrimaryDark)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rdPrimaryDark)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: WizardConstants.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WizardConstants.buttonCornerRadius)
                    .strokeBorder(Color.rdPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wizard Create Event Button

/// Bottom create event button with gradient
struct WizardCreateEventButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Event")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: WizardConstants.primaryGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(WizardConstants.buttonCornerRadius)
            }
            .disabled(isLoading)
            .padding(.horizontal, WizardConstants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // Home indicator space
            Color.clear.frame(height: 34)
        }
        .background(
            Color.rdBackground
                .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        )
    }
}

// MARK: - Previews

#Preview("Back Button") {
    WizardBackButton(action: {})
        .padding()
}

#Preview("Skip Button") {
    WizardSkipButton(action: {})
        .padding()
}

#Preview("Continue Button") {
    VStack(spacing: 16) {
        WizardContinueButton(action: {})
        WizardContinueButton("Next Step", isEnabled: false, action: {})
    }
}

#Preview("Generate Button") {
    WizardGenerateButton("Generate Agenda", action: {})
        .padding()
}
