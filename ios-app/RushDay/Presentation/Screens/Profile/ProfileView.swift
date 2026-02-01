import SwiftUI

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showLogoutAlert = false
    @Published var isLoggingOut = false
    @Published var appVersion: String = ""

    private let authService: AuthServiceProtocol
    private let grpcService: GRPCClientService

    init(
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        grpcService: GRPCClientService = .shared
    ) {
        self.authService = authService
        self.grpcService = grpcService
        loadAppVersion()
    }

    private func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version) (\(build))"
        }
    }

    private func ensureAuthToken() async {
        guard let firebaseUser = authService.currentFirebaseUser else {
            return
        }

        do {
            let token = try await firebaseUser.getIDToken(forcingRefresh: false)
            grpcService.setAuthToken(token)
        } catch {
            // Token refresh failed
        }
    }


    func signOut() {
        isLoggingOut = true
        defer { isLoggingOut = false }

        do {
            try authService.signOut()
        } catch {
            // Sign out failed
        }
    }

}

// MARK: - Profile Screen
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showNotificationSettings = false
    @State private var notificationConfig: NotificationConfiguration?
    @State private var editProfileUser: User?
    @State private var showLanguageSelection = false
    @State private var showPaywall = false
    @State private var showDebugConsole = false
    @State private var showContactUs = false

    /// Use centralized user from AppState
    private var user: User? { appState.currentUser }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar Section
                ProfileAvatarSection(user: user, isSubscribed: appState.isSubscribed)
                    .padding(.top, 12)

                // Name Section
                ProfileNameSection(name: user?.displayName)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                // Paywall Banner (only show for non-subscribers)
                if !appState.isSubscribed {
                    PaywallBanner {
                        showPaywall = true
                    }
                    .padding(.bottom, 24)
                }

                // Email Section
                ProfileEmailSection(email: user?.email)
                    .padding(.bottom, 24)

                // Actions Section
                ProfileActionsSection(
                    appVersion: viewModel.appVersion,
                    currentLanguage: localizationManager.displayLanguageName,
                    onNotificationsTap: {
                        notificationConfig = user?.notificationConfiguration
                        showNotificationSettings = true
                    },
                    onContactUsTap: { showContactUs = true },
                    onLanguageTap: { showLanguageSelection = true },
                    onTermsTap: { openTermsOfService() },
                    onPrivacyTap: { openPrivacyPolicy() },
                    onLogoutTap: { viewModel.showLogoutAlert = true },
                    onDebugTap: { showDebugConsole = true }
                )
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 16)
        }
        .scrollBounceHaptic()
        .background(Color.rdBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.edit) {
                    editProfileUser = user
                }
                .font(.rdBody(.large))
                .fontWeight(.semibold)
                .foregroundColor(.rdPrimaryDark)
            }
        }
        .navigationDestination(isPresented: $showLanguageSelection) {
            LanguageSelectionView()
        }
        .navigationDestination(isPresented: $showContactUs) {
            ContactUsView()
        }
        .navigationDestination(isPresented: $showDebugConsole) {
            DebugView()
        }
        .navigationDestination(isPresented: $showNotificationSettings) {
            NotificationSettingsView(
                configuration: notificationConfig
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallScreen(source: "profile") {
                appState.updateSubscriptionStatus(true)
            }
        }
        .id(localizationManager.refreshTrigger)
        .alert(L10n.areYouSure, isPresented: $viewModel.showLogoutAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.logOut, role: .destructive) {
                viewModel.signOut()
                dismiss()
            }
        } message: {
            Text(L10n.logOutDesc)
        }
        .task {
            // Load user data if not already loaded
            if appState.currentUser == nil {
                await appState.loadCurrentUser()
            }
        }
        .navigationDestination(item: $editProfileUser) { editUser in
            EditProfileView(user: editUser)
        }
    }

    private func openTermsOfService() {
        if let url = URL(string: "https://rush-day.io/terms-of-service") {
            openURL(url)
        }
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://rush-day.io/privacy-policy") {
            openURL(url)
        }
    }
}

// MARK: - Profile Avatar Section
struct ProfileAvatarSection: View {
    let user: User?
    let isSubscribed: Bool
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            // Avatar - 96px as per Figma design
            ProfileAvatarView(user: user)
                .frame(width: 96, height: 96)
                .scaleEffect(scale)

            // Pro badge for premium users
            if isSubscribed {
                ProBadge()
            }
        }
    }
}

// MARK: - Pro Badge
struct ProBadge: View {
    // Gradient colors from Figma
    private let gradientStart = Color(red: 161/255, green: 123/255, blue: 244/255) // #A17BF4
    private let gradientEnd = Color(red: 130/255, green: 81/255, blue: 235/255) // #8251EB

    var body: some View {
        // Star symbol + "Pro" text combined
        Text("\(Image(systemName: "star.fill")) Pro")
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ProfileAvatarView: View {
    let user: User?

    var body: some View {
        if let photoURL = user?.photoURL, !photoURL.isEmpty {
            CachedAsyncImage(url: URL(string: photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProfileAvatarPlaceholder(user: user)
            }
            .clipShape(Circle())
            .id(photoURL) // Force view recreation when URL changes
        } else {
            ProfileAvatarPlaceholder(user: user)
        }
    }
}

struct ProfileAvatarPlaceholder: View {
    let user: User?

    // Gray color from Figma: #9C9CA6 at 20% opacity
    private let placeholderBackground = Color(red: 156/255, green: 156/255, blue: 166/255).opacity(0.2)
    private let iconColor = Color(red: 158/255, green: 158/255, blue: 170/255) // #9E9EAA

    var body: some View {
        ZStack {
            Circle()
                .fill(placeholderBackground)

            if let initials = user?.initials {
                Text(initials)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(iconColor)
            } else {
                Image("ic_user_placeholder")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 64, height: 64)
            }
        }
    }
}

// MARK: - Profile Name Section
struct ProfileNameSection: View {
    let name: String?

    var body: some View {
        ProfileInfoCard {
            Text(name ?? "No Name")
                .font(.rdBody(.large))
                .foregroundColor(.rdTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Profile Email Section
struct ProfileEmailSection: View {
    let email: String?

    var body: some View {
        ProfileInfoCard {
            HStack {
                Text(L10n.email)
                    .font(.rdBody(.large))
                    .foregroundColor(.rdTextPrimary)

                Spacer()

                Text(email ?? "-")
                    .font(.rdBody(.large))
                    .foregroundColor(.rdTextSecondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Profile Info Card
struct ProfileInfoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.rdBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Profile Actions Section
struct ProfileActionsSection: View {
    let appVersion: String
    let currentLanguage: String
    let onNotificationsTap: () -> Void
    let onContactUsTap: () -> Void
    let onLanguageTap: () -> Void
    let onTermsTap: () -> Void
    let onPrivacyTap: () -> Void
    let onLogoutTap: () -> Void
    var onDebugTap: (() -> Void)? = nil

    private var isDevMode: Bool {
        AppConfig.shared.isDevMode
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileActionRow(
                iconName: "ic_bell",
                title: L10n.notifications,
                trailing: .chevron,
                position: .first,
                action: onNotificationsTap
            )

            ProfileDivider()

            ProfileActionRow(
                iconName: "ic_mail_edit",
                title: L10n.contactUs,
                trailing: .chevron,
                action: onContactUsTap
            )

            ProfileDivider()

            // Language row hidden for now
            // ProfileActionRow(
            //     iconName: "ic_globe",
            //     title: L10n.language,
            //     trailing: .textWithChevron(currentLanguage),
            //     action: onLanguageTap
            // )
            // ProfileDivider()

            ProfileActionRow(
                iconName: "ic_shield",
                title: L10n.termsOfService,
                trailing: .chevron,
                action: onTermsTap
            )

            ProfileDivider()

            ProfileActionRow(
                iconName: "ic_file",
                title: L10n.privacyPolicy,
                trailing: .chevron,
                action: onPrivacyTap
            )

            ProfileDivider()

            ProfileActionRow(
                iconName: "ic_logout",
                title: L10n.logOut,
                trailing: .chevron,
                action: onLogoutTap
            )

            ProfileDivider()

            ProfileActionRow(
                iconName: "ic_info",
                title: L10n.appVersion,
                trailing: .text(appVersion),
                position: isDevMode ? .middle : .last,
                action: {}
            )

            // Debug option (always available in DEBUG builds)
            #if DEBUG
            ProfileDivider()

            ProfileActionRow(
                iconName: "ant.fill",
                isSystemIcon: true,
                title: "Debug Console",
                trailing: .chevron,
                position: .last,
                action: { onDebugTap?() }
            )
            #endif
        }
        .background(Color.rdBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Profile Action Row
enum ProfileRowPosition {
    case first
    case middle
    case last
}

enum ProfileRowTrailing {
    case chevron
    case text(String)
    case textWithChevron(String)
}

struct ProfileActionRow: View {
    let iconName: String
    var isSystemIcon: Bool = false
    let title: String
    let trailing: ProfileRowTrailing
    var position: ProfileRowPosition = .middle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSystemIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.rdPrimaryDark)
                        .frame(width: 24, height: 24)
                } else {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.rdPrimaryDark)
                        .frame(width: 24, height: 24)
                }

                Text(title)
                    .font(.rdBody(.large))
                    .foregroundColor(.rdTextPrimary)

                Spacer()

                trailingView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.rdDivider)

        case .text(let text):
            Text(text)
                .font(.rdBody(.large))
                .foregroundColor(.rdTextTertiary)
                .padding(.trailing, 8)

        case .textWithChevron(let text):
            HStack(spacing: 8) {
                Text(text)
                    .font(.rdBody(.large))
                    .foregroundColor(.rdTextTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rdDivider)
            }
        }
    }
}

// MARK: - Profile Divider
struct ProfileDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}

// MARK: - Language Selection View
// NOTE: Language selection is currently disabled - will be enabled later when localization is ready
struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(LocalizationManager.supportedLanguages.enumerated()), id: \.element.code) { index, language in
                    Button(action: {
                        localizationManager.setLanguage(language.code)
                    }) {
                        HStack {
                            Text(language.name)
                                .font(.rdBody(.large))
                                .foregroundColor(.rdTextPrimary)

                            Spacer()

                            if isLanguageSelected(language.code) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.rdPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < LocalizationManager.supportedLanguages.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.rdBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
        .scrollBounceHaptic()
        .background(Color.rdBackground)
        .navigationTitle(L10n.language)
        .navigationBarTitleDisplayMode(.inline)
        .id(localizationManager.refreshTrigger)
    }

    private func isLanguageSelected(_ code: String) -> Bool {
        let currentLang = localizationManager.currentLanguage
        // Handle variants like pt-BR matching pt, zh-Hans matching zh
        if code == currentLang { return true }
        if code.hasPrefix(currentLang) || currentLang.hasPrefix(code.replacingOccurrences(of: "-", with: "").prefix(2).description) {
            return code == LocalizationManager.supportedLanguages.first { $0.code.hasPrefix(currentLang) || currentLang.hasPrefix($0.code.prefix(2).description) }?.code
        }
        return false
    }
}

// MARK: - Paywall Banner
struct PaywallBanner: View {
    let onTap: () -> Void

    // Colors from Figma
    private let gradientStart = Color(red: 161/255, green: 123/255, blue: 244/255) // #A17BF4
    private let gradientEnd = Color(red: 130/255, green: 81/255, blue: 235/255) // #8251EB
    private let starColor = Color(red: 185/255, green: 214/255, blue: 0/255) // #B9D600
    private let decorStarColor = Color(red: 225/255, green: 211/255, blue: 255/255) // #E1D3FF

    // Attributed string for title with mixed font weights
    private var titleAttributedString: AttributedString {
        var result = AttributedString("Unlock More with ")
        result.font = .system(size: 17, weight: .medium)
        result.foregroundColor = .white

        var boldPart = AttributedString("RushDay Pro")
        boldPart.font = .system(size: 17, weight: .bold)
        boldPart.foregroundColor = .white

        result.append(boldPart)
        return result
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient - 197.151deg angle from Figma
                LinearGradient(
                    stops: [
                        .init(color: gradientStart, location: 0.22479),
                        .init(color: gradientEnd, location: 0.77521)
                    ],
                    startPoint: UnitPoint(x: 0.65, y: 0),
                    endPoint: UnitPoint(x: 0.35, y: 1)
                )

                // Decorative elements (aligned to trailing edge)
                VStack {
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .overlay(alignment: .trailing) {
                    ZStack {
                        // ic_plans - moved more left
                        Image("ic_plans")
                            .resizable()
                            .frame(width: 67.5, height: 52.73)
                            .rotationEffect(.degrees(16.411))
                            .offset(x: -55, y: 24)

                        // ic_clipboard - rotated -15deg
                        Image("ic_clipboard")
                            .resizable()
                            .frame(width: 73.75, height: 76.23)
                            .rotationEffect(.degrees(-15))
                            .offset(x: 10, y: -5)

                        // Star decorations (opacity 0.2) - moved right
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.88, green: 0.83, blue: 1))
                            .rotationEffect(.degrees(15))
                            .opacity(0.2)
                            .offset(x: -45, y: -35)

                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.88, green: 0.83, blue: 1))
                            .rotationEffect(.degrees(-15))
                            .opacity(0.2)
                            .offset(x: -75, y: -38)
                    }
                    .padding(.trailing, 10)
                }

                // Main content
                HStack(alignment: .center) {
                    // Star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 24))
                        .foregroundColor(starColor)
                        .padding(.trailing, 8)

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleAttributedString)

                        Text("Plan in Minutes, Not Hours")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                    }

                    Spacer(minLength: 8)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}


