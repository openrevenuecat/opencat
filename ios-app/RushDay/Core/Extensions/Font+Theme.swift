import SwiftUI

extension Font {
    // MARK: - Display
    static let displayLarge = Font.system(size: 34, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let displaySmall = Font.system(size: 24, weight: .bold)

    // MARK: - Headline
    static let headlineLarge = Font.system(size: 22, weight: .semibold)
    static let headlineMedium = Font.system(size: 20, weight: .semibold)
    static let headlineSmall = Font.system(size: 18, weight: .semibold)

    // MARK: - Title
    static let titleLarge = Font.system(size: 17, weight: .medium)
    static let titleMedium = Font.system(size: 16, weight: .medium)
    static let titleSmall = Font.system(size: 15, weight: .medium)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // MARK: - Label
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 12, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)

    // MARK: - Caption
    static let captionLarge = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .regular)
    static let captionSmall = Font.system(size: 10, weight: .regular)

    // MARK: - RD Helper Functions (default to medium size)
    static func rdDisplay(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .displayLarge
        case .medium: return .displayMedium
        case .small: return .displaySmall
        }
    }

    static func rdHeadline(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .headlineLarge
        case .medium: return .headlineMedium
        case .small: return .headlineSmall
        }
    }

    static func rdTitle(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .titleLarge
        case .medium: return .titleMedium
        case .small: return .titleSmall
        }
    }

    static func rdBody(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .bodyLarge
        case .medium: return .bodyMedium
        case .small: return .bodySmall
        }
    }

    static func rdLabel(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .labelLarge
        case .medium: return .labelMedium
        case .small: return .labelSmall
        }
    }

    static func rdCaption(_ size: RDFontSize = .medium) -> Font {
        switch size {
        case .large: return .captionLarge
        case .medium: return .captionMedium
        case .small: return .captionSmall
        }
    }
}

enum RDFontSize {
    case large
    case medium
    case small
}

// MARK: - View Modifiers
extension View {
    func textStyle(_ style: TextStyle) -> some View {
        self.font(style.font)
            .foregroundColor(style.color)
    }

    /// Sets the line height (line spacing) for text
    /// - Parameter lineHeight: The desired line height in points (total height including font size)
    /// Note: This approximates line height. For precise typography, use .lineSpacing() directly
    func lineHeight(_ lineHeight: CGFloat) -> some View {
        // Line spacing is the extra space between lines
        // For a font size of 28pt with line height 34pt, we need spacing of 6pt
        // This is an approximation since we don't know the exact font size in this context
        self.lineSpacing(max(0, lineHeight * 0.2))
    }
}

enum TextStyle {
    case displayLarge
    case displayMedium
    case displaySmall
    case headlineLarge
    case headlineMedium
    case headlineSmall
    case titleLarge
    case titleMedium
    case titleSmall
    case bodyLarge
    case bodyMedium
    case bodySmall
    case labelLarge
    case labelMedium
    case labelSmall
    case captionLarge
    case captionMedium
    case captionSmall

    var font: Font {
        switch self {
        case .displayLarge: return .displayLarge
        case .displayMedium: return .displayMedium
        case .displaySmall: return .displaySmall
        case .headlineLarge: return .headlineLarge
        case .headlineMedium: return .headlineMedium
        case .headlineSmall: return .headlineSmall
        case .titleLarge: return .titleLarge
        case .titleMedium: return .titleMedium
        case .titleSmall: return .titleSmall
        case .bodyLarge: return .bodyLarge
        case .bodyMedium: return .bodyMedium
        case .bodySmall: return .bodySmall
        case .labelLarge: return .labelLarge
        case .labelMedium: return .labelMedium
        case .labelSmall: return .labelSmall
        case .captionLarge: return .captionLarge
        case .captionMedium: return .captionMedium
        case .captionSmall: return .captionSmall
        }
    }

    var color: Color {
        switch self {
        case .displayLarge, .displayMedium, .displaySmall,
             .headlineLarge, .headlineMedium, .headlineSmall,
             .titleLarge, .titleMedium, .titleSmall:
            return .rdTextPrimary
        case .bodyLarge, .bodyMedium, .bodySmall:
            return .rdTextPrimary
        case .labelLarge, .labelMedium, .labelSmall:
            return .rdTextSecondary
        case .captionLarge, .captionMedium, .captionSmall:
            return .rdTextTertiary
        }
    }
}
