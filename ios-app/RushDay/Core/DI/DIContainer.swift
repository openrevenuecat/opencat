import Foundation
import FirebaseAuth

/// Dependency Injection Container
/// Provides singleton access to all services and repositories
final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    // MARK: - Services
    lazy var authService: AuthServiceProtocol = FirebaseAuthServiceImpl()
    lazy var firestoreService: FirestoreServiceProtocol = FirestoreServiceImpl()
    lazy var storageService: StorageServiceProtocol = FirebaseStorageServiceImpl()
    lazy var notificationService: NotificationServiceProtocol = FCMNotificationServiceImpl()
    lazy var contactsService: ContactsServiceProtocol = ContactsServiceImpl()
    lazy var revenueCatService: SubscriptionServiceProtocol = OpenCatServiceImpl()
    lazy var migrationService: MigrationServiceProtocol = MigrationServiceImpl(
        migrationAPI: GRPCMigrationAPI()
    )

    // MARK: - Repositories
    lazy var userRepository: UserRepositoryProtocol = UserRepositoryImpl(
        firestoreService: firestoreService,
        authService: authService
    )

    lazy var eventRepository: EventRepositoryProtocol = EventRepositoryImpl(
        firestoreService: firestoreService
    )

    lazy var guestRepository: GuestRepositoryProtocol = GuestRepositoryImpl()

    lazy var taskRepository: TaskRepositoryProtocol = TaskRepositoryImpl()

    lazy var expenseRepository: ExpenseRepositoryProtocol = ExpenseRepositoryImpl()

    lazy var agendaRepository: AgendaRepositoryProtocol = AgendaRepositoryImpl()

    lazy var notificationNetworkService: NotificationNetworkServiceProtocol = NotificationNetworkService()

    lazy var notificationRepository: NotificationRepositoryProtocol = NotificationRepositoryImpl(
        networkService: notificationNetworkService,
        fcmService: notificationService as! FCMNotificationServiceImpl
    )
}

// MARK: - Service Protocols
protocol AuthServiceProtocol {
    var currentUser: User? { get }
    var currentFirebaseUser: FirebaseAuth.User? { get }
    var isAuthenticated: Bool { get }

    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String, name: String) async throws -> User
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User
    func signOut() throws
    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> Any
    func removeAuthStateListener(_ handle: Any)
}

protocol FirestoreServiceProtocol {
    func get<T: Codable>(collection: String, documentId: String) async throws -> T
    func getAll<T: Codable>(collection: String) async throws -> [T]
    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any) async throws -> [T]
    func create<T: Codable>(collection: String, data: T) async throws -> String
    func update<T: Codable>(collection: String, documentId: String, data: T) async throws
    func delete(collection: String, documentId: String) async throws

    // Flutter pattern methods
    func createWithGeneratedId<T: Codable>(collection: String, data: T) async throws -> String
    func updateFields(collection: String, documentId: String, fields: [String: Any]) async throws
    func addToArrayField(collection: String, documentId: String, field: String, value: Any) async throws
    func removeFromArrayField(collection: String, documentId: String, field: String, value: Any) async throws
    func getByIds<T: Codable>(collection: String, documentIds: [String]) async throws -> [T]

    // Subcollection operations (Flutter pattern)
    func getSubcollection<T: Codable>(collection: String, documentId: String, subcollection: String) async throws -> [T]
    func createInSubcollection<T: Codable>(collection: String, documentId: String, subcollection: String, data: T) async throws -> String
    func createInSubcollectionWithId<T: Codable>(collection: String, documentId: String, subcollection: String, subDocumentId: String, data: T) async throws
    func deleteSubcollectionDocument(collection: String, documentId: String, subcollection: String, subDocumentId: String) async throws
    func deleteAllInSubcollection(collection: String, documentId: String, subcollection: String) async throws

    // User device tokens (for sending push notifications to other users)
    func getFcmTokens(userId: String) async throws -> [String]
}

protocol StorageServiceProtocol {
    func uploadImage(data: Data, path: String) async throws -> String
    func downloadImage(path: String) async throws -> Data
    func deleteFile(path: String) async throws
}

protocol NotificationServiceProtocol {
    func registerForPushNotifications() async throws -> String?
    func scheduleLocalNotification(title: String, body: String, date: Date) async throws
    func getToken() async -> String?
    var cachedToken: String? { get }
}

protocol ContactsServiceProtocol {
    var isAuthorized: Bool { get }
    func requestAccess() async throws -> Bool
    func fetchContacts() async throws -> [AppContact]
    func searchContacts(query: String) async throws -> [AppContact]
}

// Note: Service implementations are in Core/Services/Firebase/ and Core/Services/Contacts/
