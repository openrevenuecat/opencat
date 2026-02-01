import Foundation
import GRPC
import NIO
import NIOCore
import SwiftProtobuf

// MARK: - GRPCClientService

/// Service for managing gRPC connections to the Rushday backend
public final class GRPCClientService {

    // MARK: - Properties

    private let group: EventLoopGroup
    private var channel: GRPCChannel?

    private var userClient: Rushday_V1_UserServiceNIOClient?
    private var eventClient: Rushday_V1_EventServiceNIOClient?
    private var vendorClient: Rushday_V1_VendorServiceNIOClient?
    private var invitationClient: Rushday_V1_InvitationServiceNIOClient?
    private var aiPlannerClient: Rushday_V1_AIEventPlannerServiceNIOClient?

    private var authToken: String?
    private var currentHost: String = ""
    private var currentPort: Int = 0

    // MARK: - Configuration

    public struct Configuration {
        let host: String
        let port: Int
        let useTLS: Bool

        public init(host: String, port: Int, useTLS: Bool = true) {
            self.host = host
            self.port = port
            self.useTLS = useTLS
        }

        public static let development = Configuration(
            host: "backend-grpc-dev-576581738729.us-west1.run.app",
            port: 443,
            useTLS: true
        )

        /// For testing on physical device connecting to Mac's local backend
        public static let localNetwork = Configuration(
            host: "192.168.88.88",
            port: 50051,
            useTLS: false
        )

        public static let production = Configuration(
            host: "api.rushday.app",
            port: 443,
            useTLS: true
        )
    }

    // MARK: - Singleton

    public static let shared = GRPCClientService()

    // MARK: - Init

    private init() {
        self.group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    }

    deinit {
        try? channel?.close().wait()
        try? group.syncShutdownGracefully()
    }

    // MARK: - Connection

    /// Connect to the gRPC server
    public func connect(configuration: Configuration) throws {
        // Use ClientConnection instead of GRPCChannelPool for better long-running stream handling
        let builder: ClientConnection.Builder
        if configuration.useTLS {
            builder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
        } else {
            builder = ClientConnection.insecure(group: group)
        }

        channel = builder
            // Configure HTTP/2 keepalive to prevent connection timeouts during long operations
            .withKeepalive(ClientConnectionKeepalive(
                interval: .seconds(20),      // Send keepalive ping every 20 seconds (more aggressive)
                timeout: .seconds(10),       // Wait 10 seconds for pong response
                permitWithoutCalls: true,    // Send pings even when no RPCs are in flight
                maximumPingsWithoutData: 0   // No limit on pings without data
            ))
            .withConnectionIdleTimeout(.minutes(10))
            .withConnectionReestablishment(enabled: true)
            .connect(host: configuration.host, port: configuration.port)

        // Store host info for logging
        currentHost = configuration.host
        currentPort = configuration.port

        guard let channel = channel else { return }

        // Initialize clients
        userClient = Rushday_V1_UserServiceNIOClient(channel: channel)
        eventClient = Rushday_V1_EventServiceNIOClient(channel: channel)
        vendorClient = Rushday_V1_VendorServiceNIOClient(channel: channel)
        invitationClient = Rushday_V1_InvitationServiceNIOClient(channel: channel)
        aiPlannerClient = Rushday_V1_AIEventPlannerServiceNIOClient(channel: channel)
    }

    /// Disconnect from the gRPC server
    public func disconnect() {
        try? channel?.close().wait()
        channel = nil
        userClient = nil
        eventClient = nil
        vendorClient = nil
        invitationClient = nil
        aiPlannerClient = nil
    }

    /// Update the authentication token
    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Call Options

    private func makeCallOptions() -> CallOptions {
        var options = CallOptions()
        if let token = authToken {
            // Note: gRPC metadata keys are case-insensitive, but some servers expect lowercase
            options.customMetadata.add(name: "authorization", value: "Bearer \(token)")
        }
        return options
    }

    // MARK: - Logged gRPC Call Helper

    /// Execute a gRPC call with network logging and optional retry
    private func loggedCall<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        service: String,
        method: String,
        request: Request,
        retryPolicy: RetryPolicy = .default,
        call: @escaping () async throws -> Response
    ) async throws -> Response {
        let endpoint = "/\(service)/\(method)"
        let host = "\(currentHost):\(currentPort)"

        // Format request body for logging
        var requestBody: String? = nil
        if let jsonData = try? request.jsonUTF8Data(),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            requestBody = jsonString
        }

        // Build headers for logging
        var headers: [String: String] = [:]
        if authToken != nil {
            headers["authorization"] = "Bearer <token>"
        }

        let startTime = Date()

        // Capture for Sendable closure
        let logHeaders = headers
        let logRequestBody = requestBody

        // Log the request
        let logId = await MainActor.run {
            NetworkLogger.shared.logRequest(
                method: "gRPC",
                endpoint: endpoint,
                host: host,
                headers: logHeaders,
                requestBody: logRequestBody
            )
        }

        do {
            // Execute with retry
            let response = try await RetryExecutor.shared.execute(policy: retryPolicy) {
                try await call()
            }

            let duration = Date().timeIntervalSince(startTime)

            // Format response body for logging
            let logResponseBody: String?
            if let jsonData = try? response.jsonUTF8Data(),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                logResponseBody = jsonString
            } else {
                logResponseBody = nil
            }

            // Log success
            await MainActor.run {
                NetworkLogger.shared.logResponse(
                    id: logId,
                    status: "OK",
                    responseBody: logResponseBody,
                    duration: duration
                )
            }

            return response
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Log error
            await MainActor.run {
                NetworkLogger.shared.logError(
                    id: logId,
                    error: error.localizedDescription,
                    duration: duration
                )
            }

            throw error
        }
    }

    /// Execute a gRPC call without retry (for operations that shouldn't be retried)
    private func loggedCallNoRetry<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        service: String,
        method: String,
        request: Request,
        call: @escaping () async throws -> Response
    ) async throws -> Response {
        try await loggedCall(service: service, method: method, request: request, retryPolicy: .none, call: call)
    }

    // MARK: - User Service

    public func getCurrentUser() async throws -> Rushday_V1_User {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }
        let request = Rushday_V1_GetCurrentUserRequest()
        return try await loggedCall(service: "UserService", method: "GetCurrentUser", request: request) {
            try await client.getCurrentUser(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateUser(_ request: Rushday_V1_UpdateUserRequest) async throws -> Rushday_V1_User {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }

        return try await loggedCall(service: "UserService", method: "UpdateUser", request: request) {
            try await client.updateUser(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateNotificationPreferences(_ request: Rushday_V1_UpdateNotificationPreferencesRequest) async throws -> Rushday_V1_User {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "UserService", method: "UpdateNotificationPreferences", request: request) {
            try await client.updateNotificationPreferences(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func registerDevice(_ request: Rushday_V1_RegisterDeviceRequest) async throws -> Rushday_V1_User {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "UserService", method: "RegisterDevice", request: request) {
            try await client.registerDevice(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteUser() async throws -> Rushday_V1_DeleteUserResponse {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }
        let request = Rushday_V1_DeleteUserRequest()
        return try await loggedCall(service: "UserService", method: "DeleteUser", request: request) {
            try await client.deleteUser(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func migrateUserData(appVersion: String) async throws -> Rushday_V1_MigrateUserDataResponse {
        guard let client = userClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_MigrateUserDataRequest()
        request.appVersion = appVersion
        return try await loggedCall(service: "UserService", method: "MigrateUserData", request: request) {
            try await client.migrateUserData(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Event Service

    public func createEvent(_ request: Rushday_V1_CreateEventRequest) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateEvent", request: request) {
            try await client.createEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func getEvent(id: String) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetEventRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "GetEvent", request: request) {
            try await client.getEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listEvents(page: Int32 = 1, limit: Int32 = 20) async throws -> Rushday_V1_ListEventsResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListEventsRequest()
        request.page = page
        request.limit = limit
        return try await loggedCall(service: "EventService", method: "ListEvents", request: request) {
            try await client.listEvents(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Streams events in batches for progressive loading on home page
    /// - Parameter batchSize: Number of events per batch (default: 2)
    /// - Returns: AsyncThrowingStream of batched event responses
    public func streamEvents(batchSize: Int32 = 2) -> AsyncThrowingStream<Rushday_V1_StreamEventsResponse, Error> {
        return AsyncThrowingStream { continuation in
            guard let client = eventClient else {
                continuation.finish(throwing: GRPCError.notConnected)
                return
            }

            var request = Rushday_V1_StreamEventsRequest()
            request.batchSize = batchSize

            #if DEBUG
            print("[gRPC] StreamEvents starting with batchSize: \(batchSize)")
            #endif

            // Use the callback-based API for NIO client
            let call = client.streamEvents(request, callOptions: self.makeCallOptions()) { response in
                #if DEBUG
                print("[gRPC] StreamEvents received batch: \(response.events.count) events, isLast: \(response.isLast)")
                #endif
                continuation.yield(response)
            }

            // Handle completion
            call.status.whenComplete { result in
                switch result {
                case .success(let status):
                    if status.isOk {
                        #if DEBUG
                        print("[gRPC] StreamEvents completed successfully")
                        #endif
                        continuation.finish()
                    } else {
                        #if DEBUG
                        print("[gRPC] StreamEvents failed with status: \(status)")
                        #endif
                        continuation.finish(throwing: GRPCError.serverError(status.message ?? "Stream failed"))
                    }
                case .failure(let error):
                    #if DEBUG
                    print("[gRPC] StreamEvents error: \(error)")
                    #endif
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func updateEvent(_ request: Rushday_V1_UpdateEventRequest) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateEvent", request: request) {
            try await client.updateEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteEvent(id: String) async throws -> Rushday_V1_DeleteEventResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_DeleteEventRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "DeleteEvent", request: request) {
            try await client.deleteEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Task Service

    public func createTask(_ request: Rushday_V1_CreateTaskRequest) async throws -> Rushday_V1_Task {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateTask", request: request) {
            try await client.createTask(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listTasks(eventId: String, page: Int32 = 1, limit: Int32 = 50) async throws -> Rushday_V1_ListTasksResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListTasksRequest()
        request.eventID = eventId
        request.page = page
        request.limit = limit
        return try await loggedCall(service: "EventService", method: "ListTasks", request: request) {
            try await client.listTasks(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func toggleTaskDone(id: String) async throws -> Rushday_V1_Task {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ToggleTaskDoneRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "ToggleTaskDone", request: request) {
            try await client.toggleTaskDone(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateTask(_ request: Rushday_V1_UpdateTaskRequest) async throws -> Rushday_V1_Task {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateTask", request: request) {
            try await client.updateTask(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteTask(id: String) async throws -> Rushday_V1_DeleteTaskResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_DeleteTaskRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "DeleteTask", request: request) {
            try await client.deleteTask(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func reorderTasks(eventId: String, taskIds: [String]) async throws -> Rushday_V1_ReorderTasksResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ReorderTasksRequest()
        request.eventID = eventId
        request.taskIds = taskIds
        return try await loggedCall(service: "EventService", method: "ReorderTasks", request: request) {
            try await client.reorderTasks(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Guest Service

    public func createGuest(_ request: Rushday_V1_CreateGuestRequest) async throws -> Rushday_V1_Guest {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateGuest", request: request) {
            try await client.createGuest(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listGuests(eventId: String, status: Rushday_V1_GuestStatus? = nil) async throws -> Rushday_V1_ListGuestsResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListGuestsRequest()
        request.eventID = eventId
        if let status = status {
            request.status = status
        }
        return try await loggedCall(service: "EventService", method: "ListGuests", request: request) {
            try await client.listGuests(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func batchCreateGuests(_ request: Rushday_V1_BatchCreateGuestsRequest) async throws -> Rushday_V1_BatchCreateGuestsResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "BatchCreateGuests", request: request) {
            try await client.batchCreateGuests(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func getGuest(guestId: String) async throws -> Rushday_V1_Guest {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetGuestRequest()
        request.id = guestId
        return try await loggedCall(service: "EventService", method: "GetGuest", request: request) {
            try await client.getGuest(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateGuest(_ request: Rushday_V1_UpdateGuestRequest) async throws -> Rushday_V1_Guest {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateGuest", request: request) {
            try await client.updateGuest(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteGuest(guestId: String) async throws -> Rushday_V1_DeleteGuestResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_DeleteGuestRequest()
        request.id = guestId
        return try await loggedCall(service: "EventService", method: "DeleteGuest", request: request) {
            try await client.deleteGuest(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Guest Invitation Service

    /// Create a shareable guest invitation link
    /// - Parameters:
    ///   - guestId: The guest ID
    ///   - eventId: The event ID
    ///   - message: Optional custom message for the invitation
    /// - Returns: GuestInvitation with pre-generated invite link
    public func createGuestInvitation(guestId: String, eventId: String, message: String? = nil) async throws -> Rushday_V1_GuestInvitation {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_CreateGuestInvitationRequest()
        request.guestID = guestId
        request.eventID = eventId
        if let message = message {
            request.message = message
        }
        return try await loggedCall(service: "EventService", method: "CreateGuestInvitation", request: request) {
            try await client.createGuestInvitation(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Get public guest invitation data (no auth required - for web viewer)
    /// - Parameter encodedData: Base64 URL encoded invitation data
    /// - Returns: Public invitation details for display
    public func getPublicGuestInvitation(encodedData: String) async throws -> Rushday_V1_PublicGuestInvitation {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetPublicGuestInvitationRequest()
        request.encodedData = encodedData
        // Note: This is a public endpoint, no auth needed
        return try await loggedCall(service: "EventService", method: "GetPublicGuestInvitation", request: request) {
            try await client.getPublicGuestInvitation(request).response.get()
        }
    }

    // MARK: - Agenda Service

    public func createAgenda(_ request: Rushday_V1_CreateAgendaRequest) async throws -> Rushday_V1_Agenda {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateAgenda", request: request) {
            try await client.createAgenda(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listAgendas(eventId: String) async throws -> Rushday_V1_ListAgendasResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListAgendasRequest()
        request.eventID = eventId
        return try await loggedCall(service: "EventService", method: "ListAgendas", request: request) {
            try await client.listAgendas(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateAgenda(_ request: Rushday_V1_UpdateAgendaRequest) async throws -> Rushday_V1_Agenda {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateAgenda", request: request) {
            try await client.updateAgenda(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteAgenda(id: String) async throws -> Rushday_V1_DeleteAgendaResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_DeleteAgendaRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "DeleteAgenda", request: request) {
            try await client.deleteAgenda(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Budget Service

    public func createBudget(_ request: Rushday_V1_CreateBudgetRequest) async throws -> Rushday_V1_Budget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateBudget", request: request) {
            try await client.createBudget(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listBudgets(eventId: String) async throws -> Rushday_V1_ListBudgetsResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListBudgetsRequest()
        request.eventID = eventId
        return try await loggedCall(service: "EventService", method: "ListBudgets", request: request) {
            try await client.listBudgets(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateBudget(_ request: Rushday_V1_UpdateBudgetRequest) async throws -> Rushday_V1_Budget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateBudget", request: request) {
            try await client.updateBudget(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func deleteBudget(id: String) async throws -> Rushday_V1_DeleteBudgetResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_DeleteBudgetRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "DeleteBudget", request: request) {
            try await client.deleteBudget(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func addPayment(_ request: Rushday_V1_AddPaymentRequest) async throws -> Rushday_V1_Budget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "AddPayment", request: request) {
            try await client.addPayment(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func removePayment(_ request: Rushday_V1_RemovePaymentRequest) async throws -> Rushday_V1_Budget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "RemovePayment", request: request) {
            try await client.removePayment(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Event Budget Service

    public func getEventBudget(eventId: String) async throws -> Rushday_V1_EventBudget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetEventBudgetRequest()
        request.eventID = eventId
        return try await loggedCall(service: "EventService", method: "GetEventBudget", request: request) {
            try await client.getEventBudget(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func upsertEventBudget(eventId: String, plannedBudget: Double, currencyCode: String = "USD", currencySymbol: String = "$") async throws -> Rushday_V1_EventBudget {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_UpsertEventBudgetRequest()
        request.eventID = eventId
        request.plannedBudget = plannedBudget
        request.currencyCode = currencyCode
        request.currencySymbol = currencySymbol
        return try await loggedCall(service: "EventService", method: "UpsertEventBudget", request: request) {
            try await client.upsertEventBudget(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Draft Event Service

    public func createDraftEvent(_ request: Rushday_V1_CreateDraftEventRequest) async throws -> Rushday_V1_DraftEvent {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "CreateDraftEvent", request: request) {
            try await client.createDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func getDraftEvent(id: String) async throws -> Rushday_V1_DraftEvent {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetDraftEventRequest()
        request.id = id
        return try await loggedCall(service: "EventService", method: "GetDraftEvent", request: request) {
            try await client.getDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func updateDraftEvent(_ request: Rushday_V1_UpdateDraftEventRequest) async throws -> Rushday_V1_DraftEvent {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "EventService", method: "UpdateDraftEvent", request: request) {
            try await client.updateDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listDraftEvents(page: Int32 = 1, limit: Int32 = 20) async throws -> Rushday_V1_ListDraftEventsResponse {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListDraftEventsRequest()
        request.page = page
        request.limit = limit
        return try await loggedCall(service: "EventService", method: "ListDraftEvents", request: request) {
            try await client.listDraftEvents(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Vendor Service

    public func createVendor(_ request: Rushday_V1_CreateVendorRequest) async throws -> Rushday_V1_Vendor {
        guard let client = vendorClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "VendorService", method: "CreateVendor", request: request) {
            try await client.createVendor(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func listVendors(page: Int32 = 1, limit: Int32 = 20) async throws -> Rushday_V1_ListVendorsResponse {
        guard let client = vendorClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ListVendorsRequest()
        request.page = page
        request.limit = limit
        return try await loggedCall(service: "VendorService", method: "ListVendors", request: request) {
            try await client.listVendors(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - Invitation Service

    public func createInvitation(_ request: Rushday_V1_CreateInvitationRequest) async throws -> Rushday_V1_Invitation {
        guard let client = invitationClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "InvitationService", method: "CreateInvitation", request: request) {
            try await client.createInvitation(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    public func getPublicInvitation(id: String) async throws -> Rushday_V1_PublicInvitation {
        guard let client = invitationClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetPublicInvitationRequest()
        request.id = id
        // Note: This is a public endpoint, no auth needed
        return try await loggedCall(service: "InvitationService", method: "GetPublicInvitation", request: request) {
            try await client.getPublicInvitation(request).response.get()
        }
    }

    // MARK: - AI Event Planner Service

    /// Generate event plans with streaming response
    /// Returns an AsyncThrowingStream that yields progress updates and plans
    public func generateEventPlansStreaming(
        _ request: Rushday_V1_GenerateEventPlansRequest
    ) -> AsyncThrowingStream<Rushday_V1_GenerateEventPlansStreamResponse, Error> {
        AsyncThrowingStream { continuation in
            guard let client = self.aiPlannerClient else {
                continuation.finish(throwing: GRPCError.notConnected)
                return
            }

            var options = self.makeCallOptions()
            options.timeLimit = .timeout(.seconds(300))  // 5 minutes for AI generation

            #if DEBUG
            print("[gRPC Stream] Starting GenerateEventPlans stream")
            #endif

            // Use callback-based streaming API
            let call = client.generateEventPlans(request, callOptions: options) { response in
                #if DEBUG
                // Log what type of payload was received
                switch response.payload {
                case .progress(let progress):
                    print("[gRPC Stream] Received progress: \(progress.percentage)% - \(progress.message)")
                case .planSummary(let plan):
                    print("[gRPC Stream] Received plan summary: \(plan.id) - \(plan.title) (tier: \(plan.tier), style: \(plan.style))")
                case .complete(let complete):
                    print("[gRPC Stream] Received COMPLETE: generationId=\(complete.generationID), plans=\(complete.totalPlans)")
                case .error(let error):
                    print("[gRPC Stream] Received ERROR: \(error.code) - \(error.message)")
                case .none:
                    print("[gRPC Stream] Received NONE payload")
                }
                #endif
                continuation.yield(response)
            }

            // Handle cancellation when stream consumer stops (prevents "transport is closing" errors)
            continuation.onTermination = { @Sendable termination in
                #if DEBUG
                print("[gRPC Stream] Termination: \(termination)")
                #endif
                if case .cancelled = termination {
                    call.cancel(promise: nil)
                }
            }

            // Handle completion
            call.status.whenComplete { result in
                #if DEBUG
                print("[gRPC Stream] Status complete: \(result)")
                #endif
                switch result {
                case .success(let status):
                    if status.isOk {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: GRPCError.serverError(status.message ?? "Unknown error"))
                    }
                case .failure(let error):
                    #if DEBUG
                    print("[gRPC Stream] Failure error: \(error)")
                    #endif
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Result type for non-streaming plan generation (returns summaries)
    public struct GeneratePlansResult {
        public let generationId: String
        public let plans: [Rushday_V1_EventPlanSummary]
        public let processingTimeMs: Int64
    }

    /// Non-streaming version that collects all plan summaries
    /// Use generateEventPlansStreaming for real-time progress updates
    public func generateEventPlans(_ request: Rushday_V1_GenerateEventPlansRequest) async throws -> GeneratePlansResult {
        var plans: [Rushday_V1_EventPlanSummary] = []
        var generationId = ""
        var processingTime: Int64 = 0

        for try await response in generateEventPlansStreaming(request) {
            switch response.payload {
            case .planSummary(let plan):
                plans.append(plan)
            case .complete(let complete):
                generationId = complete.generationID
                processingTime = complete.processingTimeMs
            case .error(let error):
                throw GRPCError.serverError(error.message)
            case .progress:
                // Ignore progress in non-streaming mode
                break
            case .none:
                break
            }
        }

        guard !plans.isEmpty else {
            throw GRPCError.serverError("No plans generated")
        }

        return GeneratePlansResult(
            generationId: generationId,
            plans: plans,
            processingTimeMs: processingTime
        )
    }

    public func getGeneratedPlans(generationId: String) async throws -> Rushday_V1_GenerateEventPlansResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetGeneratedPlansRequest()
        request.generationID = generationId
        return try await loggedCall(service: "AIEventPlannerService", method: "GetGeneratedPlans", request: request) {
            try await client.getGeneratedPlans(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Get full plan details (Step 2 - on demand when user selects a plan)
    public func getPlanDetails(generationId: String, planId: String) async throws -> Rushday_V1_EventPlan {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetPlanDetailsRequest()
        request.generationID = generationId
        request.planID = planId

        let response: Rushday_V1_GetPlanDetailsResponse = try await loggedCall(service: "AIEventPlannerService", method: "GetPlanDetails", request: request) {
            try await client.getPlanDetails(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success, response.hasPlan else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to get plan details" : response.errorMessage)
        }

        return response.plan
    }

    public func createEventFromPlan(_ request: Rushday_V1_CreateEventFromPlanRequest) async throws -> Rushday_V1_CreateEventFromPlanResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        return try await loggedCall(service: "AIEventPlannerService", method: "CreateEventFromPlan", request: request) {
            try await client.createEventFromPlan(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Generate agenda items for an existing event using AI
    /// - Parameters:
    ///   - eventId: The event ID to generate agenda for
    ///   - replaceExisting: If true, deletes existing items first; if false, appends
    ///   - existingTitles: Titles of existing agenda items to avoid duplicates
    public func generateAgenda(eventId: String, replaceExisting: Bool = false, existingTitles: [String] = []) async throws -> Rushday_V1_GenerateAgendaResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GenerateAgendaRequest()
        request.eventID = eventId
        request.replaceExisting = replaceExisting
        request.existingTitles = existingTitles

        return try await loggedCall(service: "AIEventPlannerService", method: "GenerateAgenda", request: request) {
            try await client.generateAgenda(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Generate/recalculate expenses for an existing event using AI
    public func generateExpenses(eventId: String, replaceExisting: Bool = false, currentAgendaItems: [String] = []) async throws -> Rushday_V1_GenerateExpensesResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GenerateExpensesRequest()
        request.eventID = eventId
        request.replaceExisting = replaceExisting
        request.currentAgendaItems = currentAgendaItems

        return try await loggedCall(service: "AIEventPlannerService", method: "GenerateExpenses", request: request) {
            try await client.generateExpenses(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Create a draft event from AI wizard (hidden from user's event list until published)
    /// - Parameters:
    ///   - sessionId: Device/session ID for anonymous drafts (required if user not authenticated)
    public func createAIDraftEvent(
        name: String,
        eventType: String,
        date: Date,
        budgetPlan: Int64,
        guestsPlan: Int32,
        coverImage: String? = nil,
        sessionId: String? = nil,
        budgetMin: Int64? = nil,
        budgetMax: Int64? = nil,
        venue: String? = nil
    ) async throws -> Rushday_V1_CreateAIDraftEventResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_CreateAIDraftEventRequest()
        request.name = name
        request.eventType = eventType
        request.date = Google_Protobuf_Timestamp(date: date)
        request.budgetPlan = budgetPlan
        request.guestsPlan = guestsPlan
        if let coverImage = coverImage {
            request.coverImage = coverImage
        }
        if let sessionId = sessionId {
            request.sessionID = sessionId
        }
        if let budgetMin = budgetMin {
            request.budgetMin = budgetMin
        }
        if let budgetMax = budgetMax {
            request.budgetMax = budgetMax
        }
        if let venue = venue {
            request.venue = venue
        }

        let response: Rushday_V1_CreateAIDraftEventResponse = try await loggedCall(service: "AIEventPlannerService", method: "CreateAIDraftEvent", request: request) {
            try await client.createAIDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to create draft event" : response.errorMessage)
        }

        return response
    }

    /// Publish a draft event (makes it visible in user's event list)
    /// - Parameters:
    ///   - sessionId: Required if draft was created anonymously (without authentication)
    public func publishAIDraftEvent(eventId: String, sessionId: String? = nil) async throws -> Rushday_V1_PublishAIDraftEventResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_PublishAIDraftEventRequest()
        request.eventID = eventId
        if let sessionId = sessionId {
            request.sessionID = sessionId
        }

        let response: Rushday_V1_PublishAIDraftEventResponse = try await loggedCall(service: "AIEventPlannerService", method: "PublishAIDraftEvent", request: request) {
            try await client.publishAIDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to publish draft event" : response.errorMessage)
        }

        return response
    }

    /// Claim an anonymous draft event after user signs in
    /// Associates the draft with the authenticated user
    public func claimDraftEvent(eventId: String, sessionId: String) async throws -> Rushday_V1_ClaimDraftEventResponse {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ClaimDraftEventRequest()
        request.eventID = eventId
        request.sessionID = sessionId

        let response: Rushday_V1_ClaimDraftEventResponse = try await loggedCall(service: "AIEventPlannerService", method: "ClaimDraftEvent", request: request) {
            try await client.claimDraftEvent(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to claim draft event" : response.errorMessage)
        }

        return response
    }

    /// Generate an AI invitation message for an event
    /// - Parameter eventId: The event to generate a message for
    /// - Returns: Generated invitation message text
    public func generateInviteMessage(eventId: String) async throws -> String {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GenerateInviteMessageRequest()
        request.eventID = eventId

        let response: Rushday_V1_GenerateInviteMessageResponse = try await loggedCall(service: "AIEventPlannerService", method: "GenerateInviteMessage", request: request) {
            try await client.generateInviteMessage(request, callOptions: self.makeCallOptions()).response.get()
        }

        return response.message
    }

    // MARK: - Event Sharing Service

    /// Share an event with a new co-host (generates a unique secret for the invite link)
    /// - Parameters:
    ///   - eventId: The event to share
    ///   - name: Name of the person being invited
    /// - Returns: Updated Event with the new SharedUser added (contains secret for invite link)
    public func shareEvent(eventId: String, name: String) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_ShareEventRequest()
        request.eventID = eventId
        request.name = name
        return try await loggedCall(service: "EventService", method: "ShareEvent", request: request) {
            try await client.shareEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Accept a shared event invitation using the secret from the invite link
    /// - Parameter secret: The unique secret from the invite link
    /// - Returns: The Event that was joined
    public func acceptSharedEvent(secret: String) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_AcceptSharedEventRequest()
        request.secret = secret
        return try await loggedCall(service: "EventService", method: "AcceptSharedEvent", request: request) {
            try await client.acceptSharedEvent(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Remove a co-host from an event
    /// - Parameters:
    ///   - eventId: The event ID
    ///   - secret: The secret of the SharedUser to remove
    /// - Returns: Updated Event with the SharedUser removed
    public func removeSharedUser(eventId: String, secret: String) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_RemoveSharedUserRequest()
        request.eventID = eventId
        request.secret = secret
        return try await loggedCall(service: "EventService", method: "RemoveSharedUser", request: request) {
            try await client.removeSharedUser(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    /// Update a shared user's access role
    /// - Parameters:
    ///   - eventId: The event ID
    ///   - secret: The secret of the SharedUser to update
    ///   - accessRole: The new access role ("admin" or "viewer")
    /// - Returns: Updated Event with the SharedUser updated
    public func updateSharedUser(eventId: String, secret: String, accessRole: String) async throws -> Rushday_V1_Event {
        guard let client = eventClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_UpdateSharedUserRequest()
        request.eventID = eventId
        request.secret = secret
        request.accessRole = accessRole
        return try await loggedCall(service: "EventService", method: "UpdateSharedUser", request: request) {
            try await client.updateSharedUser(request, callOptions: self.makeCallOptions()).response.get()
        }
    }

    // MARK: - AI Chat Service

    /// Result from sending a chat message
    public struct ChatMessageResult {
        public let message: Rushday_V1_ChatMessage
        public let checklist: Rushday_V1_ChatChecklist?
        public let hintText: String
        public let suggestedTopics: [String]
        public let conversationId: String
        public let suggestedAction: Rushday_V1_SuggestedAction?
        public let toolExecutions: [Rushday_V1_ToolExecution]
    }

    /// Send a chat message and get AI response (non-streaming)
    public func sendChatMessage(
        eventId: String,
        message: String,
        topic: Rushday_V1_ChatTopic = .general,
        conversationId: String? = nil
    ) async throws -> ChatMessageResult {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_SendChatMessageRequest()
        request.eventID = eventId
        request.message = message
        request.topic = topic
        if let conversationId = conversationId {
            request.conversationID = conversationId
        }

        let response: Rushday_V1_SendChatMessageResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "SendChatMessage",
            request: request
        ) {
            try await client.sendChatMessage(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to send message" : response.errorMessage)
        }

        return ChatMessageResult(
            message: response.responseMessage,
            checklist: response.hasChecklist ? response.checklist : nil,
            hintText: response.hintText,
            suggestedTopics: response.suggestedTopics,
            conversationId: response.conversationID,
            suggestedAction: response.hasSuggestedAction ? response.suggestedAction : nil,
            toolExecutions: response.toolExecutions
        )
    }

    /// Send a chat message with streaming response
    public func sendChatMessageStream(
        eventId: String,
        message: String,
        topic: Rushday_V1_ChatTopic = .general
    ) -> AsyncThrowingStream<Rushday_V1_ChatStreamResponse, Error> {
        AsyncThrowingStream { continuation in
            guard let client = self.aiPlannerClient else {
                continuation.finish(throwing: GRPCError.notConnected)
                return
            }

            var request = Rushday_V1_SendChatMessageRequest()
            request.eventID = eventId
            request.message = message
            request.topic = topic

            var options = self.makeCallOptions()
            options.timeLimit = .timeout(.seconds(120))

            let call = client.sendChatMessageStream(request, callOptions: options) { response in
                continuation.yield(response)
            }

            // Handle cancellation when stream consumer stops (prevents "transport is closing" errors)
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    call.cancel(promise: nil)
                }
            }

            call.status.whenComplete { result in
                switch result {
                case .success(let status):
                    if status.isOk {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: GRPCError.serverError(status.message ?? "Unknown error"))
                    }
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Result from generating a topic checklist
    public struct TopicChecklistResult {
        public let message: Rushday_V1_ChatMessage
    }

    /// Generate a checklist for a specific topic
    public func generateTopicChecklist(
        eventId: String,
        topic: Rushday_V1_ChatTopic
    ) async throws -> TopicChecklistResult {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GenerateTopicChecklistRequest()
        request.eventID = eventId
        request.topic = topic

        let response: Rushday_V1_GenerateTopicChecklistResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "GenerateTopicChecklist",
            request: request
        ) {
            try await client.generateTopicChecklist(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to generate checklist" : response.errorMessage)
        }

        return TopicChecklistResult(
            message: response.message
        )
    }

    /// Save a checklist to the event
    public func saveChecklist(eventId: String, checklistId: String) async throws {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_SaveChecklistRequest()
        request.eventID = eventId
        request.checklistID = checklistId

        let response: Rushday_V1_SaveChecklistResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "SaveChecklist",
            request: request
        ) {
            try await client.saveChecklist(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to save checklist" : response.errorMessage)
        }
    }

    /// Unsave a checklist from the event
    public func unsaveChecklist(eventId: String, checklistId: String) async throws {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_UnsaveChecklistRequest()
        request.eventID = eventId
        request.checklistID = checklistId

        let response: Rushday_V1_UnsaveChecklistResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "UnsaveChecklist",
            request: request
        ) {
            try await client.unsaveChecklist(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to unsave checklist" : response.errorMessage)
        }
    }

    /// Get chat history for an event, optionally filtered by conversation
    public func getChatHistory(
        eventId: String,
        conversationId: String? = nil,
        limit: Int32 = 50,
        cursor: String? = nil
    ) async throws -> (messages: [Rushday_V1_ChatMessage], hasMore: Bool) {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetChatHistoryRequest()
        request.eventID = eventId
        request.limit = limit
        if let conversationIdValue = conversationId {
            request.conversationID = conversationIdValue
        }
        if let cursorValue = cursor {
            request.cursor = cursorValue
        }

        let response: Rushday_V1_GetChatHistoryResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "GetChatHistory",
            request: request
        ) {
            try await client.getChatHistory(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to get chat history" : response.errorMessage)
        }

        return (messages: response.messages, hasMore: response.hasMore_p)
    }

    /// Get saved checklists for an event
    public func getSavedChecklists(eventId: String) async throws -> [Rushday_V1_ChatChecklist] {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetSavedChecklistsRequest()
        request.eventID = eventId

        let response: Rushday_V1_GetSavedChecklistsResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "GetSavedChecklists",
            request: request
        ) {
            try await client.getSavedChecklists(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to get saved checklists" : response.errorMessage)
        }

        return response.checklists
    }

    // MARK: - Saved Conversations

    /// Save a conversation to an event
    public func saveConversation(eventId: String, conversationId: String, title: String? = nil) async throws -> Rushday_V1_SavedConversation {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_SaveConversationRequest()
        request.eventID = eventId
        request.conversationID = conversationId
        if let title = title {
            request.title = title
        }

        let response: Rushday_V1_SaveConversationResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "SaveConversation",
            request: request
        ) {
            try await client.saveConversation(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to save conversation" : response.errorMessage)
        }

        return response.conversation
    }

    /// Unsave a conversation from an event
    public func unsaveConversation(eventId: String, conversationId: String) async throws {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_UnsaveConversationRequest()
        request.eventID = eventId
        request.conversationID = conversationId

        let response: Rushday_V1_UnsaveConversationResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "UnsaveConversation",
            request: request
        ) {
            try await client.unsaveConversation(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to unsave conversation" : response.errorMessage)
        }
    }

    /// Get saved conversations for an event
    public func getSavedConversations(eventId: String) async throws -> [Rushday_V1_SavedConversation] {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetSavedConversationsRequest()
        request.eventID = eventId

        let response: Rushday_V1_GetSavedConversationsResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "GetSavedConversations",
            request: request
        ) {
            try await client.getSavedConversations(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to get saved conversations" : response.errorMessage)
        }

        return response.conversations
    }

    /// Update a checklist item's checked state
    public func updateChecklistItem(
        eventId: String,
        checklistId: String,
        itemId: String,
        isChecked: Bool
    ) async throws {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_UpdateChecklistItemRequest()
        request.eventID = eventId
        request.checklistID = checklistId
        request.itemID = itemId
        request.isChecked = isChecked

        let response: Rushday_V1_UpdateChecklistItemResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "UpdateChecklistItem",
            request: request
        ) {
            try await client.updateChecklistItem(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to update checklist item" : response.errorMessage)
        }
    }

    /// Result from getting chat hints
    public struct ChatHintsResult {
        public let primaryHint: String
        public let suggestedHints: [String]
    }

    /// Get AI-generated contextual hints for chat input
    public func getChatHints(
        eventId: String,
        conversationId: String? = nil,
        lastTopic: Rushday_V1_ChatTopic? = nil
    ) async throws -> ChatHintsResult {
        guard let client = aiPlannerClient else {
            throw GRPCError.notConnected
        }
        var request = Rushday_V1_GetChatHintsRequest()
        request.eventID = eventId
        if let conversationId = conversationId {
            request.conversationID = conversationId
        }
        if let lastTopic = lastTopic {
            request.lastTopic = lastTopic
        }

        let response: Rushday_V1_GetChatHintsResponse = try await loggedCall(
            service: "AIEventPlannerService",
            method: "GetChatHints",
            request: request
        ) {
            try await client.getChatHints(request, callOptions: self.makeCallOptions()).response.get()
        }

        guard response.success else {
            throw GRPCError.serverError(response.errorMessage.isEmpty ? "Failed to get chat hints" : response.errorMessage)
        }

        return ChatHintsResult(
            primaryHint: response.primaryHint,
            suggestedHints: response.suggestedHints
        )
    }
}

// MARK: - GRPCError

public enum GRPCError: LocalizedError {
    case notConnected
    case invalidResponse
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the server. Please call connect() first."
        case .invalidResponse:
            return "Invalid response from the server."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
