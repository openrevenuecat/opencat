import SwiftUI
import Combine

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    @MainActor static let shared = LocalizationManager()

    // Supported languages with their display names
    static let supportedLanguages: [(name: String, code: String)] = [
        ("English", "en"),
        ("Español", "es"),
        ("Français", "fr"),
        ("Deutsch", "de"),
        ("Italiano", "it"),
        ("Português", "pt-BR"),
        ("Русский", "ru"),
        ("中文", "zh-Hans")
    ]

    @Published private(set) var currentLanguage: String = "en"
    @Published private(set) var currentLocale: Locale = .current
    @Published private(set) var refreshTrigger: UUID = UUID()

    private var storedLanguage: String {
        get { UserDefaults.standard.string(forKey: "appLanguage") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "appLanguage") }
    }

    private let lock = NSLock()
    private var currentBundle: Bundle = .main
    private var translationsCache: [String: String] = [:]

    private init() {
        loadSavedLanguage()
    }

    private func loadSavedLanguage() {
        // Force English for all users (localization disabled for now)
        currentLanguage = "en"
        currentLocale = Locale(identifier: "en")
        updateBundle(for: "en")
    }

    @MainActor
    func setLanguage(_ languageCode: String) {
        // Localization disabled - always use English
        // This function is kept for API compatibility but does nothing
    }

    private func updateBundle(for languageCode: String) {
        // Try to find the .lproj bundle for the language
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            lock.lock()
            currentBundle = bundle
            lock.unlock()
        } else {
            lock.lock()
            currentBundle = .main
            lock.unlock()
        }
    }

    private func mapToBundleLanguage(_ code: String) -> String {
        switch code {
        case "pt", "pt-BR":
            return "pt-BR"
        case "zh", "zh-Hans", "zh-CN":
            return "zh-Hans"
        case "zh-Hant", "zh-TW":
            return "zh-Hant"
        default:
            return code
        }
    }

    func localizedString(for key: String) -> String {
        lock.lock()

        // Check cache first
        if let cached = translationsCache[key] {
            lock.unlock()
            return cached
        }

        let bundle = currentBundle
        lock.unlock()

        // Use NSLocalizedString with explicit bundle and table
        // Pass a unique marker as value so we can detect if key wasn't found
        let notFoundMarker = "##NOT_FOUND##\(key)"
        let result = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: notFoundMarker, comment: "")

        if result == notFoundMarker {
            // Key not found in bundle, return the key itself
            return key
        }

        // Cache the result
        lock.lock()
        translationsCache[key] = result
        lock.unlock()

        return result
    }

    func localizedString(for key: String, with arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }

    var isSystemLanguage: Bool {
        storedLanguage == "system"
    }

    @MainActor
    var displayLanguageName: String {
        // Localization disabled - always return English
        return "English"
    }
}

// MARK: - Environment Key
@MainActor
private struct LocalizationManagerKey: @preconcurrency EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    @MainActor
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}
