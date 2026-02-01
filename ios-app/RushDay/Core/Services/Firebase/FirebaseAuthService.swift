import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Firebase Auth Service
class FirebaseAuthServiceImpl: AuthServiceProtocol {
    private let auth = Auth.auth()
    private var currentNonce: String?

    var currentUser: User? {
        guard let firebaseUser = auth.currentUser else { return nil }
        return mapFirebaseUser(firebaseUser)
    }

    var currentFirebaseUser: FirebaseAuth.User? {
        auth.currentUser
    }

    var isAuthenticated: Bool {
        auth.currentUser != nil
    }

    // MARK: - Email/Password Auth

    func signInWithEmail(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return mapFirebaseUser(result.user)
    }

    func signUpWithEmail(email: String, password: String, name: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)

        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()

        return mapFirebaseUser(result.user)
    }

    // MARK: - Apple Sign In

    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await auth.signIn(with: credential)
        return mapFirebaseUser(result.user)
    }

    // MARK: - Google Sign In

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await auth.signIn(with: credential)
        return mapFirebaseUser(result.user)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    // MARK: - Auth State Listener

    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> Any {
        return auth.addStateDidChangeListener { _, firebaseUser in
            if let firebaseUser = firebaseUser {
                listener(self.mapFirebaseUser(firebaseUser))
            } else {
                listener(nil)
            }
        }
    }

    func removeAuthStateListener(_ handle: Any) {
        if let handle = handle as? AuthStateDidChangeListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Helper Methods

    private func mapFirebaseUser(_ firebaseUser: FirebaseAuth.User) -> User {
        User(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "",
            email: firebaseUser.email ?? "",
            photoUrl: firebaseUser.photoURL?.absoluteString,
            createAt: firebaseUser.metadata.creationDate ?? Date(),
            updateAt: firebaseUser.metadata.lastSignInDate
        )
    }

    // MARK: - Apple Sign In Helpers

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case userNotFound
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No user found with this email"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknown(let message):
            return message
        }
    }
}
