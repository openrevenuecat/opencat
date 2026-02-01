import Foundation
import FirebaseFirestore

// MARK: - Firestore Service Implementation
class FirestoreServiceImpl: FirestoreServiceProtocol {
    private let db = Firestore.firestore()

    // MARK: - Get Single Document

    func get<T: Codable>(collection: String, documentId: String) async throws -> T {
        let document = try await db.collection(collection).document(documentId).getDocument()

        guard document.exists else {
            throw FirestoreError.documentNotFound
        }

        guard let data = document.data() else {
            throw FirestoreError.invalidData
        }

        return try decode(data, documentId: documentId)
    }

    // MARK: - Get All Documents

    func getAll<T: Codable>(collection: String) async throws -> [T] {
        let snapshot = try await db.collection(collection).getDocuments()

        return try snapshot.documents.compactMap { document in
            try decode(document.data(), documentId: document.documentID)
        }
    }

    // MARK: - Query Documents

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any) async throws -> [T] {
        let snapshot = try await db.collection(collection)
            .whereField(field, isEqualTo: value)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            try decode(document.data(), documentId: document.documentID)
        }
    }

    // MARK: - Query with Multiple Conditions

    func queryMultiple<T: Codable>(
        collection: String,
        conditions: [(field: String, op: QueryOperator, value: Any)],
        orderBy: String? = nil,
        descending: Bool = false,
        limit: Int? = nil
    ) async throws -> [T] {
        var query: Query = db.collection(collection)

        for condition in conditions {
            switch condition.op {
            case .isEqualTo:
                query = query.whereField(condition.field, isEqualTo: condition.value)
            case .isNotEqualTo:
                query = query.whereField(condition.field, isNotEqualTo: condition.value)
            case .isLessThan:
                query = query.whereField(condition.field, isLessThan: condition.value)
            case .isLessThanOrEqualTo:
                query = query.whereField(condition.field, isLessThanOrEqualTo: condition.value)
            case .isGreaterThan:
                query = query.whereField(condition.field, isGreaterThan: condition.value)
            case .isGreaterThanOrEqualTo:
                query = query.whereField(condition.field, isGreaterThanOrEqualTo: condition.value)
            case .arrayContains:
                query = query.whereField(condition.field, arrayContains: condition.value)
            case .inArray:
                if let array = condition.value as? [Any] {
                    query = query.whereField(condition.field, in: array)
                }
            }
        }

        if let orderBy = orderBy {
            query = query.order(by: orderBy, descending: descending)
        }

        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { document in
            try decode(document.data(), documentId: document.documentID)
        }
    }

    // MARK: - Create Document

    func create<T: Codable>(collection: String, data: T) async throws -> String {
        let encoded = try encode(data)
        let documentRef = try await db.collection(collection).addDocument(data: encoded)
        return documentRef.documentID
    }

    // MARK: - Create Document with Custom ID (Flutter pattern)
    /// Creates a document with auto-generated ID and returns the ID
    /// This matches Flutter's pattern: doc() then set()

    func createWithGeneratedId<T: Codable>(collection: String, data: T) async throws -> String {
        let docRef = db.collection(collection).document()
        let documentId = docRef.documentID
        var encoded = try encode(data)
        encoded["id"] = documentId  // Store the ID in the document itself (Flutter pattern)
        try await docRef.setData(encoded)
        return documentId
    }

    // MARK: - Create Document with ID

    func createWithId<T: Codable>(collection: String, documentId: String, data: T) async throws {
        let encoded = try encode(data)
        try await db.collection(collection).document(documentId).setData(encoded)
    }

    // MARK: - Update Document

    func update<T: Codable>(collection: String, documentId: String, data: T) async throws {
        let encoded = try encode(data)
        try await db.collection(collection).document(documentId).setData(encoded, merge: true)
    }

    // MARK: - Update Specific Fields

    func updateFields(collection: String, documentId: String, fields: [String: Any]) async throws {
        try await db.collection(collection).document(documentId).updateData(fields)
    }

    // MARK: - Array Field Operations (Flutter pattern: FieldValue.arrayUnion/arrayRemove)

    func addToArrayField(collection: String, documentId: String, field: String, value: Any) async throws {
        try await db.collection(collection).document(documentId).updateData([
            field: FieldValue.arrayUnion([value])
        ])
    }

    func removeFromArrayField(collection: String, documentId: String, field: String, value: Any) async throws {
        try await db.collection(collection).document(documentId).updateData([
            field: FieldValue.arrayRemove([value])
        ])
    }

    // MARK: - Delete Document

    func delete(collection: String, documentId: String) async throws {
        try await db.collection(collection).document(documentId).delete()
    }

    // MARK: - Subcollection Operations (Flutter pattern)

    func getSubcollection<T: Codable>(
        collection: String,
        documentId: String,
        subcollection: String
    ) async throws -> [T] {
        let snapshot = try await db.collection(collection)
            .document(documentId)
            .collection(subcollection)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            try decode(document.data(), documentId: document.documentID)
        }
    }

    func createInSubcollection<T: Codable>(
        collection: String,
        documentId: String,
        subcollection: String,
        data: T
    ) async throws -> String {
        let docRef = db.collection(collection)
            .document(documentId)
            .collection(subcollection)
            .document()
        let subDocId = docRef.documentID
        var encoded = try encode(data)
        encoded["id"] = subDocId
        try await docRef.setData(encoded)
        return subDocId
    }

    func createInSubcollectionWithId<T: Codable>(
        collection: String,
        documentId: String,
        subcollection: String,
        subDocumentId: String,
        data: T
    ) async throws {
        var encoded = try encode(data)
        encoded["id"] = subDocumentId
        try await db.collection(collection)
            .document(documentId)
            .collection(subcollection)
            .document(subDocumentId)
            .setData(encoded)
    }

    func deleteSubcollectionDocument(
        collection: String,
        documentId: String,
        subcollection: String,
        subDocumentId: String
    ) async throws {
        try await db.collection(collection)
            .document(documentId)
            .collection(subcollection)
            .document(subDocumentId)
            .delete()
    }

    // MARK: - Delete All Documents in Subcollection

    func deleteAllInSubcollection(
        collection: String,
        documentId: String,
        subcollection: String
    ) async throws {
        let snapshot = try await db.collection(collection)
            .document(documentId)
            .collection(subcollection)
            .getDocuments()

        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    // MARK: - User Device Tokens (for sending push notifications)

    /// Fetches FCM tokens for a specific user from their devices subcollection
    /// Path: users/{userId}/devices -> extract fcmToken from each document
    func getFcmTokens(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("devices")
            .getDocuments()

        guard !snapshot.documents.isEmpty else {
            return []
        }

        return snapshot.documents
            .compactMap { $0.data()["fcmToken"] as? String }
            .filter { !$0.isEmpty }
    }

    // MARK: - Batch Operations

    func batchWrite(operations: [BatchOperation]) async throws {
        let batch = db.batch()

        for operation in operations {
            let docRef = db.collection(operation.collection).document(operation.documentId)

            switch operation.type {
            case .create(let data):
                batch.setData(data, forDocument: docRef)
            case .update(let data):
                batch.updateData(data, forDocument: docRef)
            case .delete:
                batch.deleteDocument(docRef)
            }
        }

        try await batch.commit()
    }

    // MARK: - Get Multiple Documents by IDs (Flutter pattern)
    /// Fetches multiple documents in parallel by their IDs

    func getByIds<T: Codable>(collection: String, documentIds: [String]) async throws -> [T] {
        guard !documentIds.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: T?.self) { group in
            for docId in documentIds {
                group.addTask {
                    do {
                        return try await self.get(collection: collection, documentId: docId)
                    } catch {
                        // Fetch failed for \(docId)
                        return nil
                    }
                }
            }

            var results: [T] = []
            for try await result in group {
                if let item = result {
                    results.append(item)
                }
            }
            return results
        }
    }

    // MARK: - Real-time Listeners

    func addListener<T: Codable>(
        collection: String,
        documentId: String,
        onChange: @escaping (T?) -> Void
    ) -> ListenerRegistration {
        return db.collection(collection).document(documentId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, error == nil, let snapshot = snapshot, snapshot.exists else {
                    onChange(nil)
                    return
                }

                if let data = snapshot.data() {
                    let decoded: T? = try? self.decode(data, documentId: snapshot.documentID)
                    onChange(decoded)
                } else {
                    onChange(nil)
                }
            }
    }

    func addCollectionListener<T: Codable>(
        collection: String,
        field: String? = nil,
        isEqualTo value: Any? = nil,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        var query: Query = db.collection(collection)

        if let field = field, let value = value {
            query = query.whereField(field, isEqualTo: value)
        }

        return query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, error == nil, let snapshot = snapshot else {
                onChange([])
                return
            }

            let items: [T] = snapshot.documents.compactMap { document in
                try? self.decode(document.data(), documentId: document.documentID)
            }
            onChange(items)
        }
    }

    // MARK: - Helper Methods

    private func encode<T: Codable>(_ value: T) throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(value)
    }

    private func decode<T: Codable>(_ data: [String: Any], documentId: String) throws -> T {
        var mutableData = data
        mutableData["id"] = documentId

        let decoder = Firestore.Decoder()
        return try decoder.decode(T.self, from: mutableData)
    }
}

// MARK: - Query Operator
enum QueryOperator {
    case isEqualTo
    case isNotEqualTo
    case isLessThan
    case isLessThanOrEqualTo
    case isGreaterThan
    case isGreaterThanOrEqualTo
    case arrayContains
    case inArray
}

// MARK: - Batch Operation
struct BatchOperation {
    let collection: String
    let documentId: String
    let type: BatchOperationType
}

enum BatchOperationType {
    case create([String: Any])
    case update([String: Any])
    case delete
}

// MARK: - Firestore Errors
enum FirestoreError: LocalizedError {
    case documentNotFound
    case invalidData
    case encodingError
    case decodingError
    case permissionDenied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid document data"
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        case .permissionDenied:
            return "Permission denied"
        case .unknown(let message):
            return message
        }
    }
}
