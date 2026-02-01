import SwiftUI
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import CommonCrypto
import Lottie

// MARK: - Login Screen (matches Flutter login.dart)
struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dark Mode Colors

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "0D1017") : Color(hex: "F2F2F7")
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "0D1017")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title - "Sign in to Rush Day" (Figma: pl-24 pr-16, line-height 41px)
                    // Figma: content starts at top-[98px], safe area top is ~59px, so add ~39px
                    Text(L10n.signInToRushDay)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(textPrimaryColor)
                        .tracking(0.4)
                        .lineSpacing(41 - 34) // Figma: leading-[41px] for 34px font
                        .padding(.leading, 24)
                        .padding(.trailing, 16)

                    // Description (Figma: px-24, leading-[20px])
                    Text(L10n.loginDescription)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(textSecondaryColor)
                        .tracking(-0.44)
                        .lineSpacing(20 - 17) // Figma: leading-[20px] for 17px font
                        .padding(.horizontal, 24)

                    // Image Section (Figma: px-24 py-44, aspect ~1.26)
                    Image("login_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 44)

                    Spacer(minLength: 0)

                    // Action Buttons & Terms (Figma: gap-8 pb-16 px-24)
                    VStack(spacing: 8) {
                        // Sign in with Apple (Figma: wrapper h-58, button h-48)
                        AuthActionButton(
                            iconName: "apple_logo",
                            iconType: .asset,
                            title: L10n.continueWithApple,
                            action: { viewModel.signInWithApple() }
                        )
                        .frame(height: 58)

                        // Sign in with Google
                        GoogleSignInButton(
                            title: L10n.continueWithGoogle,
                            action: { viewModel.signInWithGoogle() }
                        )
                        .frame(height: 58)

                        // Privacy Policy Section (Figma: 11px, line-height 1.4)
                        VStack(spacing: 0) {
                            Text(L10n.byContinuingYouAgree)
                                .font(.system(size: 11))
                                .foregroundColor(textSecondaryColor)
                                .tracking(0.066)
                                .lineSpacing(11 * 0.4) // Figma: line-height 1.4
                            HStack(spacing: 4) {
                                Link(L10n.termsOfService, destination: URL(string: "https://rush-day.io/terms-of-service")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(textSecondaryColor)
                                    .underline()
                                Text(L10n.and)
                                    .font(.system(size: 11))
                                    .foregroundColor(textSecondaryColor)
                                Link(L10n.privacyPolicy, destination: URL(string: "https://rush-day.io/privacy-policy")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(textSecondaryColor)
                                    .underline()
                            }
                            .lineSpacing(11 * 0.4) // Figma: line-height 1.4
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16) // Figma: pb-16 above home indicator
                }
                // Figma dimensions (screen 393x852):
                // - Navigation bar: 98px (includes 53px status bar + 45px extra)
                // - Content ends at: y=767
                // - Home indicator: y=818, height=34px
                // - Total bottom space (content to screen edge): 852 - 767 = 85px
                // iOS safe area bottom ~34px, need additional padding to match Figma
                .padding(.top, max(0, 98 - geometry.safeAreaInsets.top))
                .padding(.bottom, max(0, 85 - geometry.safeAreaInsets.bottom))

                // Loading Overlay with Lottie Animation (matches Flutter login.dart)
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    LottieView(animation: .named("star", bundle: .main))
                        .looping()
                        .frame(width: 150, height: 150)
                        .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .alert(L10n.error, isPresented: $viewModel.showError) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onChange(of: viewModel.signedInUser) { _, user in
            if let user = user {
                appState.handleSuccessfulSignIn(user: user, isNewUser: viewModel.isNewUser)
            }
        }
    }
}

// MARK: - Auth Action Button (Styled like Flutter CustomButton.white)
struct AuthActionButton: View {
    let iconName: String
    let iconType: IconType
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    enum IconType {
        case system
        case asset
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var buttonTextColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }

    private var buttonBorderColor: Color {
        colorScheme == .dark ? Color(hex: "B9D600").opacity(0.8) : Color(hex: "B9D600")
    }

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            action()
        }) {
            HStack(spacing: 4) {
                switch iconType {
                case .system:
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                case .asset:
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 21, height: 24)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .lineSpacing(20 - 15) // Figma: leading-[20px] for 15px font
            }
            .foregroundColor(buttonTextColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(buttonBackgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buttonBorderColor, lineWidth: 1)
            )
            // Figma: shadow-[0px_4px_8px_-4px_rgba(23,15,13,0.04)]
            .shadow(color: Color(hex: "170F0D").opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 4, x: 0, y: 4)
            // Figma: shadow-[0px_12px_18px_-6px_rgba(23,15,13,0.08)]
            .shadow(color: Color(hex: "170F0D").opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 9, x: 0, y: 12)
        }
    }
}

// MARK: - Google Sign In Button
struct GoogleSignInButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1F2937") : Color.white
    }

    private var buttonTextColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }

    private var buttonBorderColor: Color {
        colorScheme == .dark ? Color(hex: "B9D600").opacity(0.8) : Color(hex: "B9D600")
    }

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            action()
        }) {
            HStack(spacing: 4) {
                Image("google_logo")
                    .resizable()
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .lineSpacing(20 - 15) // Figma: leading-[20px] for 15px font
            }
            .foregroundColor(buttonTextColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(buttonBackgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buttonBorderColor, lineWidth: 1)
            )
            // Figma: shadow-[0px_4px_8px_-4px_rgba(23,15,13,0.04)]
            .shadow(color: Color(hex: "170F0D").opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 4, x: 0, y: 4)
            // Figma: shadow-[0px_12px_18px_-6px_rgba(23,15,13,0.08)]
            .shadow(color: Color(hex: "170F0D").opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 9, x: 0, y: 12)
        }
    }
}

// MARK: - Auth View Model
@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var signedInUser: User?
    @Published var isNewUser = false

    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol
    private var currentNonce: String?

    override init() {
        self.authService = DIContainer.shared.authService
        self.userRepository = DIContainer.shared.userRepository
        super.init()
    }

    // MARK: - Apple Sign In

    func signInWithApple() {
        isLoading = true

        let nonce = generateNonce()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        isLoading = true

        Task {
            await presentGoogleSignIn()
        }
    }

    private func presentGoogleSignIn() async {
        // Find the topmost view controller
        guard let presentingViewController = getTopViewController() else {
            isLoading = false
            errorMessage = "Unable to find view controller to present Google Sign-In"
            showError = true
            return
        }

        do {
            // Use the standard sign-in flow - Google handles showing account picker
            // If user has Google accounts on device, it shows a native bottom sheet
            // Otherwise, it opens Safari for web-based sign-in
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                isLoading = false
                errorMessage = "Failed to get Google credentials"
                showError = true
                return
            }

            await handleGoogleSignInResult(user: result.user, idToken: idToken)
        } catch {
            isLoading = false
            // Don't show error for user cancellation
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                // User cancelled - silently ignore
                return
            }
            if (error as? GIDSignInError)?.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleGoogleSignInResult(user: GIDGoogleUser, idToken: String) async {
        do {
            let accessToken = user.accessToken.tokenString
            let signedInUser = try await authService.signInWithGoogle(
                idToken: idToken,
                accessToken: accessToken
            )

            // Check if user exists in database
            let (savedUser, isNew) = try await userRepository.checkAndSaveUser(signedInUser)

            // Track registration/login with AppsFlyer
            if isNew {
                AppsFlyerService.shared.logRegistration(method: "google")
            } else {
                AppsFlyerService.shared.logLogin(method: "google")
            }

            self.isNewUser = isNew
            self.signedInUser = savedUser
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topController = window.rootViewController else {
            return nil
        }

        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    // MARK: - Nonce Generation

    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            isLoading = false
            errorMessage = "Failed to get Apple ID credentials"
            showError = true
            return
        }

        Task {
            do {
                let signedInUser = try await authService.signInWithApple(idToken: idTokenString, nonce: nonce)

                // Update display name if provided by Apple
                var userToSave = signedInUser
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !displayName.isEmpty {
                        userToSave = User(
                            id: signedInUser.id,
                            name: displayName,
                            email: signedInUser.email,
                            photoUrl: signedInUser.photoUrl,
                            currency: signedInUser.currency,
                            isPremium: signedInUser.isPremium,
                            createAt: signedInUser.createAt,
                            updateAt: signedInUser.updateAt,
                            events: signedInUser.events
                        )
                    }
                }

                // Check if user exists in database
                let (savedUser, isNew) = try await userRepository.checkAndSaveUser(userToSave)

                // Track registration/login with AppsFlyer
                if isNew {
                    AppsFlyerService.shared.logRegistration(method: "apple")
                } else {
                    AppsFlyerService.shared.logLogin(method: "apple")
                }

                self.isNewUser = isNew
                self.signedInUser = savedUser
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false

        // Don't show error for user cancellation
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }

        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(AppState())
}
