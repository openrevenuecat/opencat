import SwiftUI

// MARK: - Wizard Theme

/// Shared theme for AI Event Planner wizard
/// Provides consistent dark-mode aware colors across all wizard steps
struct WizardTheme {
    let colorScheme: ColorScheme

    // MARK: - Text Colors

    var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }

    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }

    var textTertiary: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9CA3AF")
    }

    // MARK: - Background Colors

    var background: Color {
        colorScheme == .dark ? Color(hex: "111827") : Color.rdBackground
    }

    var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }

    var cardBackgroundSolid: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    // MARK: - Border Colors

    var cardBorder: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }

    var cardBorderSelected: Color {
        Color.rdPrimary
    }

    var divider: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E5EA")
    }

    // MARK: - Accent Colors

    var accent: Color {
        Color.rdPrimary
    }

    var accentDark: Color {
        Color.rdPrimaryDark
    }

    // MARK: - Input Colors

    var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "F3F4F6")
    }

    var inputBorder: Color {
        colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DB")
    }

    var inputBorderFocused: Color {
        Color.rdPrimary
    }

    var placeholderText: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9CA3AF")
    }
}

// MARK: - Wizard Constants

/// Shared constants for AI Event Planner wizard
enum WizardConstants {
    // MARK: - Dimensions

    /// Standard header height for wizard screens (matches Figma design)
    static let headerHeight: CGFloat = 449

    /// Standard card height for option cards
    static let cardHeight: CGFloat = 65

    /// Continue/action button height
    static let buttonHeight: CGFloat = 60

    /// Standard corner radius for cards
    static let cardCornerRadius: CGFloat = 16

    /// Standard corner radius for buttons
    static let buttonCornerRadius: CGFloat = 12

    /// Standard horizontal padding
    static let horizontalPadding: CGFloat = 16

    // MARK: - Animation Timing

    /// Delay before auto-advancing to next step after selection
    static let autoAdvanceDelay: TimeInterval = 0.3

    /// Duration for step transition animations
    static let transitionDuration: TimeInterval = 0.3

    /// Duration for card selection animation
    static let selectionAnimationDuration: TimeInterval = 0.2

    // MARK: - Generation Steps

    /// Delays for each generation step animation
    static let generationStepDelays: [TimeInterval] = [1.2, 1.5, 1.5, 1.2, 1.0]

    // MARK: - Gradient Colors

    /// Primary gradient for buttons and accents (horizontal left-to-right)
    /// Figma: #8251EB → #A78BFA → #6366F1
    static let primaryGradient: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    /// Background gradient for wizard screens
    static let backgroundGradientLight: [Color] = [
        Color(hex: "F3E8FF"),
        Color(hex: "E9D5FF"),
        Color(hex: "F5F3FF")
    ]

    static let backgroundGradientDark: [Color] = [
        Color(hex: "1F2937"),
        Color(hex: "111827"),
        Color(hex: "0F172A")
    ]
}

// MARK: - Theme Environment Key

private struct WizardThemeKey: EnvironmentKey {
    static let defaultValue = WizardTheme(colorScheme: .light)
}

extension EnvironmentValues {
    var wizardTheme: WizardTheme {
        get { self[WizardThemeKey.self] }
        set { self[WizardThemeKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Applies wizard theme based on current color scheme
    func withWizardTheme() -> some View {
        modifier(WizardThemeModifier())
    }
}

private struct WizardThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.wizardTheme, WizardTheme(colorScheme: colorScheme))
    }
}
