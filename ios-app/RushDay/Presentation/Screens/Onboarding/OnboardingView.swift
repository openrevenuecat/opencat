import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    private let pages: [OnboardingPageData] = [
        // Page 1: Tasks & Agenda
        OnboardingPageData(
            backgroundImage: "onboarding_first",
            titleKey: "onboardingFirstTitle",
            descriptionKey: "onboardingFirstSubtitle",
            floatingImages: [
                // Task card: left: 29px, top: 172.71px (Figma absolute in 384px container with pt:90)
                FloatingImageData(imageName: "onboarding_task", left: 29, top: 82.71, width: 205.812, height: 155.143),
                // Agenda card: positioned right-center area, moved higher
                FloatingImageData(imageName: "onboarding_agenda", left: 143, top: -20, width: 225.429, height: 167.143)
            ]
        ),
        // Page 2: Guests
        OnboardingPageData(
            backgroundImage: "onboarding_second",
            titleKey: "onboardingSecondTitle",
            descriptionKey: "onboardingSecondSubtitle",
            floatingImages: [
                // Contact card: left: 102px, top: 49px (Figma) → top relative to pt:90 = -41
                FloatingImageData(imageName: "onboarding_contact", left: 102, top: -41, width: 245.851, height: 142.836),
                // Guest card: left: 40px, top: 167px (Figma) → top relative to pt:90 = 77, size increased
                FloatingImageData(imageName: "onboarding_guest", left: 35, top: 70, width: 235, height: 186)
            ]
        ),
        // Page 3: Budget
        OnboardingPageData(
            backgroundImage: "onboarding_third",
            titleKey: "onboardingThirdTitle",
            descriptionKey: "onboardingThirdSubtitle",
            floatingImages: [
                // Budget card: size increased
                FloatingImageData(imageName: "onboarding_budget", left: 35, top: 45, width: 240, height: 222),
                // Budget second: size increased
                FloatingImageData(imageName: "onboarding_budget_second", left: 125, top: -50, width: 250, height: 128)
            ]
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Logo overlay - independent from content layout
                VStack {
                    HStack(spacing: 8) {
                        Image("SplashIcon")
                            .resizable()
                            .frame(width: 32, height: 50)

                        Text("RushDay")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.38)
                    }
                    .padding(.top, 48)

                    Spacer()
                }

                VStack(spacing: 0) {
                    // Swipeable content area with bounce effect
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                OnboardingPageView(
                                    pageData: pages[index],
                                    screenWidth: geometry.size.width,
                                    screenHeight: geometry.size.height
                                )
                                .frame(width: geometry.size.width)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding(
                        get: { currentPage },
                        set: { if let newValue = $0 { currentPage = newValue } }
                    ))

                    // Page indicators - 44px height
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color(hex: "B9D600") : Color(hex: "E1D3FF").opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(height: 44)

                    // Button container (pt: 8, pb: 16, px: 16)
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        if currentPage < 2 {
                            withAnimation(.easeOut(duration: 0.35)) {
                                currentPage += 1
                            }
                        } else {
                            appState.completeOnboarding()
                            appState.showAIPlanner()
                        }
                    } label: {
                        Text(currentPage == 2 ? "Let's start!" : "Next")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "0D1017"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24) // 16px gap + 8px internal padding (per Figma)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Page View
struct OnboardingPageView: View {
    let pageData: OnboardingPageData
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    // Base design dimensions (iPhone 16e / Figma)
    private let baseWidth: CGFloat = 393
    private let baseHeight: CGFloat = 852

    // Scale factors for responsive layout
    private var scaleX: CGFloat { screenWidth / baseWidth }
    private var scaleY: CGFloat { screenHeight / baseHeight }

    // Uniform scale for cards - use max to prevent shrinking on smaller screens
    private var cardScale: CGFloat { max(1.0, min(scaleX, scaleY)) }

    // Responsive containerPaddingTop based on screen height
    private var containerPaddingTop: CGFloat { 210 * scaleY }

    var body: some View {
        VStack(spacing: 0) {
            // Images container
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Background wavy decoration - offset to match cards
                    Image(pageData.backgroundImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenWidth)
                        .offset(y: containerPaddingTop - (90 * scaleY)) // Move background down with cards

                    // Floating feature images with responsive positioning
                    ForEach(pageData.floatingImages.indices, id: \.self) { index in
                        let image = pageData.floatingImages[index]
                        // Use uniform cardScale for size (never shrink below design)
                        let scaledWidth = image.width * cardScale
                        let scaledHeight = image.height * cardScale
                        // Use scaleX for horizontal position, scaleY for vertical
                        let scaledLeft = image.left * scaleX
                        let scaledTop = image.top * scaleY

                        Image(image.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: scaledWidth, height: scaledHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.1), radius: 0, x: 12, y: 12)
                            .position(
                                x: scaledLeft + (scaledWidth / 2),
                                y: containerPaddingTop + scaledTop + (scaledHeight / 2)
                            )
                    }
                }
            }

            // Title & Description (anchored at bottom)
            VStack(spacing: 16) {
                // Title - expands from bottom to top
                Text(LocalizedStringKey(pageData.titleKey))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.38)
                    .lineSpacing(0)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 68, alignment: .bottom)
                    .padding(.leading, 24)
                    .padding(.trailing, 16)

                // Description - expands from top to bottom, less padding for more text per line
                Text(LocalizedStringKey(pageData.descriptionKey))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .tracking(-0.44)
                    .lineSpacing(0)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40, alignment: .top)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .frame(width: screenWidth)
    }
}

// MARK: - Data Models
struct OnboardingPageData {
    let backgroundImage: String
    let titleKey: String
    let descriptionKey: String
    let floatingImages: [FloatingImageData]
}

struct FloatingImageData {
    let imageName: String
    let left: CGFloat      // Left position from container edge
    let top: CGFloat       // Top offset (relative to containerPaddingTop)
    let width: CGFloat
    let height: CGFloat
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
