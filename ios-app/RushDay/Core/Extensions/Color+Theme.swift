import SwiftUI
import UIKit

extension Color {
    // MARK: - Primary Colors (rd prefix to avoid conflicts with SwiftUI)
    // Matching Flutter AppColor
    static let rdPrimary = Color(hex: "A17BF4") // Flutter: primary
    static let rdPrimaryLight = Color(hex: "E1D3FF") // Flutter: primaryLight
    static let rdPrimaryDark = Color(hex: "8251EB") // Flutter: primaryDark

    // MARK: - Background Colors
    static let rdBackground = Color(UIColor.systemGroupedBackground)
    static let rdBackgroundSecondary = Color(UIColor.secondarySystemGroupedBackground)
    static let rdSurface = Color(UIColor.tertiarySystemGroupedBackground)
    static let rdDivider = Color(UIColor.separator)

    // MARK: - Text Colors
    static let rdTextPrimary = Color.primary
    static let rdTextSecondary = Color.secondary
    static let rdTextTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Accent Colors
    static let rdAccent = Color(hex: "A17BF4") // Flutter: primary (purple)
    static let rdSuccess = Color(hex: "B9D600") // Flutter: lime/olive
    static let rdWarning = Color(hex: "DB4F47") // Flutter: warning
    static let rdError = Color(hex: "DB4F47") // Flutter: warning (red)


    // MARK: - Event Type Colors
    static let birthday = Color(hex: "FF6B6B")
    static let wedding = Color(hex: "C084FC")
    static let corporate = Color(hex: "38BDF8")
    static let babyShower = Color(hex: "F472B6")
    static let graduation = Color(hex: "34D399")
    static let anniversary = Color(hex: "FB923C")
    static let holiday = Color(hex: "A78BFA")
    static let conference = Color(hex: "60A5FA")
    static let vacation = Color(hex: "4ADE80")
    static let custom = Color(hex: "94A3B8")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
