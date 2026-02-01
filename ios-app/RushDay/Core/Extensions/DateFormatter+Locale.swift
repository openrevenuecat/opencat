import Foundation

extension DateFormatter {
    /// Creates a DateFormatter with English locale by default.
    /// Use this to ensure consistent date formatting regardless of device locale.
    /// When localization is implemented, this can be modified to use the app's selected locale.
    static func english(dateFormat: String? = nil) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        if let format = dateFormat {
            formatter.dateFormat = format
        }
        return formatter
    }

    /// Creates a DateFormatter with English locale for time display.
    static func englishTime() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeStyle = .short
        return formatter
    }

    /// Creates a DateFormatter with English locale for date display.
    static func englishDate(style: DateFormatter.Style = .medium) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = style
        return formatter
    }
}
