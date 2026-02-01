import SwiftUI

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    let onStart: () -> Void

    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // AI Avatar - no animation
            AIAvatarView(size: .large)

            Spacer()
                .frame(height: 32)

            // Headline
            Text("Hi! I'm Your AI\nEvent Planner")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(textPrimaryColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .tracking(0.37)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: isVisible)

            Spacer()
                .frame(height: 16)

            // Subtext
            Text("Let's create the perfect plan for your event\nin just a few simple steps")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(textSecondaryColor)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(-0.44)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: isVisible)

            Spacer()
                .frame(height: 48)

            // Feature cards
            VStack(spacing: 12) {
                WelcomeFeatureCard(
                    icon: "target",
                    text: "Personalized event plans"
                )

                WelcomeFeatureCard(
                    icon: "bolt.fill",
                    text: "Generated in 30 seconds"
                )

                WelcomeFeatureCard(
                    icon: "sparkles",
                    text: "AI recommendations & tips"
                )
            }
            .padding(.horizontal, 24)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.7), value: isVisible)

            Spacer()

            // Start button
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("Start Planning")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.44)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "8251EB"), Color(hex: "A78BFA"), Color(hex: "6366F1")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(
                    color: Color(hex: "8251EB").opacity(0.3),
                    radius: 15,
                    x: 0,
                    y: 10
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.8), value: isVisible)

            Spacer()
                .frame(height: 48)
        }
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Welcome Feature Card

struct WelcomeFeatureCard: View {
    let icon: String
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "8251EB"))
                .frame(width: 24, height: 24)

            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color.white : Color(hex: "1E2939"))
                .tracking(-0.31)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB"), lineWidth: 0.6)
                )
        )
    }
}

// MARK: - Preview

#Preview("Welcome Step") {
    WelcomeStepView(onStart: {})
        .background(
            WizardBackground()
        )
}

// MARK: - Wizard Background

struct WizardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ? [
                    Color(hex: "0D1017"),
                    Color(hex: "1A1F2E"),
                    Color(hex: "0D1017")
                ] : [
                    Color(hex: "F8F9FC"),
                    Color.white,
                    Color(hex: "F0F2F8")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // Purple blur circle (top-right)
            Circle()
                .fill(Color(hex: "8251EB").opacity(colorScheme == .dark ? 0.15 : 0.1))
                .frame(width: 384, height: 384)
                .blur(radius: 80)
                .offset(x: 150, y: -100)

            // Blue blur circle (bottom-left)
            Circle()
                .fill(Color(hex: "2B7FFF").opacity(colorScheme == .dark ? 0.15 : 0.1))
                .frame(width: 384, height: 384)
                .blur(radius: 80)
                .offset(x: -150, y: 200)
        }
        .ignoresSafeArea()
    }
}
