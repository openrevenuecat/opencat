import XCTest
@testable import RushDay

/// Integration tests for NotificationRepository with mocked services
final class NotificationRepositoryTests: XCTestCase {

    var repository: NotificationRepositoryImpl!
    var mockNetworkService: MockNotificationNetworkService!
    var mockFCMService: MockFCMNotificationService!

    override func setUp() {
        super.setUp()
        mockNetworkService = MockNotificationNetworkService()
        mockFCMService = MockFCMNotificationService()
        repository = NotificationRepositoryImpl(
            networkService: mockNetworkService,
            fcmService: mockFCMService
        )
    }

    override func tearDown() {
        repository = nil
        mockNetworkService = nil
        mockFCMService = nil
        super.tearDown()
    }

    // MARK: - Create Notification Tests

    func testCreateNotification_Success() async throws {
        let request = createTestNotificationRequest()
        mockNetworkService.createNotificationResult = .success(())

        try await repository.createNotification(request)

        XCTAssertEqual(mockNetworkService.createNotificationCallCount, 1)
        XCTAssertEqual(mockNetworkService.lastCreatedRequest?.userId, request.userId)
    }

    func testCreateNotification_Failure() async {
        let request = createTestNotificationRequest()
        mockNetworkService.createNotificationResult = .failure(MockError.networkError)

        do {
            try await repository.createNotification(request)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }

    // MARK: - Create Batch Notifications Tests

    func testCreateNotificationsBatch_Success() async throws {
        let requests = [createTestNotificationRequest(), createTestNotificationRequest()]
        mockNetworkService.createNotificationsBatchResult = .success(())

        try await repository.createNotificationsBatch(requests)

        XCTAssertEqual(mockNetworkService.createNotificationsBatchCallCount, 1)
        XCTAssertEqual(mockNetworkService.lastBatchRequests?.count, 2)
    }

    // MARK: - Delete Notifications Tests

    func testDeleteNotificationsByGroup_Success() async throws {
        mockNetworkService.deleteNotificationsByGroupResult = .success(())

        try await repository.deleteNotificationsByGroup(groupField: .eventId, groupValue: "event123")

        XCTAssertEqual(mockNetworkService.deleteByGroupCallCount, 1)
        XCTAssertEqual(mockNetworkService.lastDeleteGroupField, .eventId)
        XCTAssertEqual(mockNetworkService.lastDeleteGroupValue, "event123")
    }

    func testDeleteUserNotificationFromGroup_Success() async throws {
        mockNetworkService.deleteUserNotificationFromGroupResult = .success(())

        try await repository.deleteUserNotificationFromGroup(
            groupField: .taskId,
            groupValue: "task123",
            userId: "user456"
        )

        XCTAssertEqual(mockNetworkService.deleteUserFromGroupCallCount, 1)
    }

    // MARK: - Update Notifications Tests

    func testUpdateNotificationsByGroup_Success() async throws {
        mockNetworkService.updateNotificationsByGroupResult = .success(())
        let newSendAt = Date().addingTimeInterval(3600)

        try await repository.updateNotificationsByGroup(
            groupField: .taskId,
            groupValue: "task123",
            title: "Updated Title",
            body: "Updated Body",
            sendAt: newSendAt,
            data: nil
        )

        XCTAssertEqual(mockNetworkService.updateByGroupCallCount, 1)
    }

    // MARK: - Token Tests

    func testGetFcmToken_Success() async throws {
        mockFCMService.tokenToReturn = "test-fcm-token-123"

        let token = try await repository.getFcmToken()

        XCTAssertEqual(token, "test-fcm-token-123")
    }

    func testGetFcmToken_CachedToken() async throws {
        mockFCMService.cachedTokenValue = "cached-token-456"

        let token = try await repository.getFcmToken()

        // Should return cached token
        XCTAssertEqual(token, "cached-token-456")
    }

    func testGetFcmToken_NoToken() async throws {
        mockFCMService.tokenToReturn = nil
        mockFCMService.cachedTokenValue = nil

        let token = try await repository.getFcmToken()

        XCTAssertNil(token)
    }

    // MARK: - Toggle Type Tests

    func testToggleNotificationType_Enable() async throws {
        mockNetworkService.toggleNotificationTypeResult = .success(())

        try await repository.toggleNotificationType(userId: "user123", type: .taskReminder, enabled: true)

        XCTAssertEqual(mockNetworkService.toggleTypeCallCount, 1)
        XCTAssertEqual(mockNetworkService.lastToggleUserId, "user123")
        XCTAssertEqual(mockNetworkService.lastToggleType, .taskReminder)
        XCTAssertEqual(mockNetworkService.lastToggleEnabled, true)
    }

    func testToggleNotificationType_Disable() async throws {
        mockNetworkService.toggleNotificationTypeResult = .success(())

        try await repository.toggleNotificationType(userId: "user123", type: .eventReminder, enabled: false)

        XCTAssertEqual(mockNetworkService.lastToggleEnabled, false)
    }

    // MARK: - Adjust Time Tests

    func testEditNotificationPeriodByType_Success() async throws {
        mockNetworkService.editNotificationPeriodByTypeResult = .success(())

        try await repository.editNotificationPeriodByType(userId: "user123", type: .taskReminder, deltaMs: 3600000)

        XCTAssertEqual(mockNetworkService.editPeriodCallCount, 1)
        XCTAssertEqual(mockNetworkService.lastEditDeltaMs, 3600000)
    }

    // MARK: - Helper Methods

    private func createTestNotificationRequest() -> CreateNotificationRequest {
        return CreateNotificationRequest(
            userId: "user123",
            type: .taskReminder,
            tokens: ["token1"],
            title: "Test Notification",
            body: "Test Body",
            sendAt: Date().addingTimeInterval(3600),
            eventId: "event123",
            taskId: "task456"
        )
    }
}

// MARK: - Mock Network Service

class MockNotificationNetworkService: NotificationNetworkServiceProtocol {
    // Track method calls
    var createNotificationCallCount = 0
    var createNotificationsBatchCallCount = 0
    var updateByGroupCallCount = 0
    var deleteByGroupCallCount = 0
    var deleteUserFromGroupCallCount = 0
    var deleteBatchCallCount = 0
    var editPeriodCallCount = 0
    var toggleTypeCallCount = 0

    // Capture parameters
    var lastCreatedRequest: CreateNotificationRequest?
    var lastBatchRequests: [CreateNotificationRequest]?
    var lastDeleteGroupField: GroupField?
    var lastDeleteGroupValue: String?
    var lastToggleUserId: String?
    var lastToggleType: NotificationType?
    var lastToggleEnabled: Bool?
    var lastEditDeltaMs: Int?

    // Results
    var createNotificationResult: Result<Void, Error> = .success(())
    var createNotificationsBatchResult: Result<Void, Error> = .success(())
    var updateNotificationsByGroupResult: Result<Void, Error> = .success(())
    var deleteNotificationsByGroupResult: Result<Void, Error> = .success(())
    var deleteUserNotificationFromGroupResult: Result<Void, Error> = .success(())
    var deleteNotificationsBatchResult: Result<Void, Error> = .success(())
    var editNotificationPeriodByTypeResult: Result<Void, Error> = .success(())
    var toggleNotificationTypeResult: Result<Void, Error> = .success(())

    func createNotification(_ request: CreateNotificationRequest) async throws {
        createNotificationCallCount += 1
        lastCreatedRequest = request
        if case .failure(let error) = createNotificationResult {
            throw error
        }
    }

    func createNotificationsBatch(_ requests: [CreateNotificationRequest]) async throws {
        createNotificationsBatchCallCount += 1
        lastBatchRequests = requests
        if case .failure(let error) = createNotificationsBatchResult {
            throw error
        }
    }

    func updateNotificationsByGroup(
        groupField: GroupField,
        groupValue: String,
        title: String?,
        body: String?,
        sendAt: Date?,
        data: [String: AnyCodable]?
    ) async throws {
        updateByGroupCallCount += 1
        if case .failure(let error) = updateNotificationsByGroupResult {
            throw error
        }
    }

    func deleteNotificationsByGroup(groupField: GroupField, groupValue: String) async throws {
        deleteByGroupCallCount += 1
        lastDeleteGroupField = groupField
        lastDeleteGroupValue = groupValue
        if case .failure(let error) = deleteNotificationsByGroupResult {
            throw error
        }
    }

    func deleteUserNotificationFromGroup(
        groupField: GroupField,
        groupValue: String,
        userId: String
    ) async throws {
        deleteUserFromGroupCallCount += 1
        if case .failure(let error) = deleteUserNotificationFromGroupResult {
            throw error
        }
    }

    func deleteNotificationsBatch(_ filters: [[String: String]]) async throws {
        deleteBatchCallCount += 1
        if case .failure(let error) = deleteNotificationsBatchResult {
            throw error
        }
    }

    func editNotificationPeriodByType(userId: String, type: NotificationType, deltaMs: Int) async throws {
        editPeriodCallCount += 1
        lastEditDeltaMs = deltaMs
        if case .failure(let error) = editNotificationPeriodByTypeResult {
            throw error
        }
    }

    func toggleNotificationType(userId: String, type: NotificationType, enabled: Bool) async throws {
        toggleTypeCallCount += 1
        lastToggleUserId = userId
        lastToggleType = type
        lastToggleEnabled = enabled
        if case .failure(let error) = toggleNotificationTypeResult {
            throw error
        }
    }
}

// MARK: - Mock FCM Service

class MockFCMNotificationService: NotificationServiceProtocol {
    var tokenToReturn: String? = "mock-fcm-token"
    var cachedTokenValue: String?
    var registerCallCount = 0
    var scheduleCallCount = 0

    var cachedToken: String? {
        return cachedTokenValue
    }

    func registerForPushNotifications() async throws -> String? {
        registerCallCount += 1
        return tokenToReturn
    }

    func scheduleLocalNotification(title: String, body: String, date: Date) async throws {
        scheduleCallCount += 1
    }

    func getToken() async -> String? {
        return cachedTokenValue ?? tokenToReturn
    }
}

// MARK: - Mock Error

enum MockError: Error {
    case networkError
    case tokenError
    case unknown
}
