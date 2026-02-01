import SwiftUI

// MARK: - AI Avatar View

struct AIAvatarView: View {
    enum Size {
        case mini   // 32pt - for typing indicator
        case small  // 64pt - for step headers and chat messages
        case large  // 96pt - for welcome screen

        var dimension: CGFloat {
            switch self {
            case .mini: return 32
            case .small: return 64
            case .large: return 96
            }
        }

        var eyeWidth: CGFloat {
            switch self {
            case .mini: return 4
            case .small: return 8
            case .large: return 12
            }
        }

        var eyeHeight: CGFloat {
            switch self {
            case .mini: return 8
            case .small: return 12
            case .large: return 17
            }
        }

        var eyeSpacing: CGFloat {
            switch self {
            case .mini: return 4
            case .small: return 8
            case .large: return 12
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .mini: return 8
            case .small: return 16
            case .large: return 24
            }
        }
    }

    let size: Size
    var isAnimating: Bool = true

    // Animation states
    @State private var initialScale: CGFloat = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var leftEyeScale: CGFloat = 1.0
    @State private var rightEyeScale: CGFloat = 1.0

    private let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    private let glowGradientColors: [Color] = [
        Color(hex: "8251EB").opacity(0.3),
        Color(hex: "EC4899").opacity(0.3),  // pink-500
        Color(hex: "3B82F6").opacity(0.3)   // blue-500
    ]

    var body: some View {
        ZStack {
            // Outer glow - pulsing (matches TSX: scale [1, 1.2, 1], opacity [0.5, 0.8, 0.5])
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: glowGradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.dimension, height: size.dimension)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: size.shadowRadius)

            // Main avatar circle with shimmer
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.dimension, height: size.dimension)
                .overlay(
                    // Animated shimmer sweep
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: shimmerOffset * geometry.size.width * 1.5)
                    }
                    .clipShape(Circle())
                )
                .shadow(
                    color: Color(hex: "8251EB").opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )

            // Animated dots/eyes with staggered bounce
            HStack(spacing: size.eyeSpacing) {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: size.eyeWidth, height: size.eyeHeight)
                    .scaleEffect(y: leftEyeScale, anchor: .center)

                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: size.eyeWidth, height: size.eyeHeight)
                    .scaleEffect(y: rightEyeScale, anchor: .center)
            }
        }
        .scaleEffect(initialScale)
        .onAppear {
            if isAnimating {
                startAnimations()
            } else {
                // Set initial scale to 1 when not animating
                initialScale = 1.0
            }
        }
    }

    private func startAnimations() {
        // 1. Initial spring scale (0 → 1)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            initialScale = 1.0
        }

        // 2. Outer glow pulsing: scale [1, 1.2, 1], opacity [0.5, 0.8, 0.5]
        withAnimation(
            Animation
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            glowScale = 1.2
            glowOpacity = 0.8
        }

        // 3. Shimmer sweep animation (moves from -100% to 200%)
        withAnimation(
            Animation
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 2.0
        }

        // 4. Eye bounce animations with staggered delay
        startEyeBounceAnimation()
    }

    private func startEyeBounceAnimation() {
        // Left eye: scaleY [1, 1.4, 1], duration 0.6s
        withAnimation(
            Animation
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
        ) {
            leftEyeScale = 1.4
        }

        // Right eye: same but with 0.15s delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                rightEyeScale = 1.4
            }
        }
    }
}

// MARK: - Loading AI Avatar (for generating screen)

struct LoadingAIAvatarView: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private let size: CGFloat = 120

    private let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    var body: some View {
        ZStack {
            // Outer rotating ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "8251EB").opacity(0.1),
                            Color(hex: "8251EB").opacity(0.5),
                            Color(hex: "A78BFA"),
                            Color(hex: "8251EB").opacity(0.1)
                        ]),
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: size + 30, height: size + 30)
                .rotationEffect(.degrees(rotation))

            // Middle pulsing ring
            Circle()
                .stroke(
                    Color(hex: "8251EB").opacity(0.2),
                    lineWidth: 2
                )
                .frame(width: size + 16, height: size + 16)
                .scaleEffect(pulseScale)

            // Main avatar
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(
                    color: Color(hex: "8251EB").opacity(0.4),
                    radius: 16,
                    x: 0,
                    y: 8
                )

            // Eyes with blink animation
            AnimatedEyesView()
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Rotation animation
        withAnimation(
            Animation
                .linear(duration: 3.0)
                .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }

        // Pulse animation
        withAnimation(
            Animation
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.1
        }
    }
}

// MARK: - Animated Eyes

private struct AnimatedEyesView: View {
    @State private var eyeHeight: CGFloat = 10
    @State private var isBlinking = false

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(Color.white)
                .frame(width: 10, height: eyeHeight)

            Capsule()
                .fill(Color.white)
                .frame(width: 10, height: eyeHeight)
        }
        .onAppear {
            startBlinkAnimation()
        }
    }

    private func startBlinkAnimation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                eyeHeight = 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    eyeHeight = 10
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("AI Avatar - Large") {
    VStack(spacing: 40) {
        AIAvatarView(size: .large)
        AIAvatarView(size: .small)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Loading Avatar") {
    LoadingAIAvatarView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
