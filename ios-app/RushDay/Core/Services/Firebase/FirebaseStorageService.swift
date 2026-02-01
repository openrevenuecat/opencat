import Foundation
import FirebaseStorage
import UIKit

// MARK: - Firebase Storage Service Implementation
class FirebaseStorageServiceImpl: StorageServiceProtocol {
    // Use the same bucket as Flutter app (rushday_bucket for prod)
    // The default bucket from GoogleService-Info.plist is different
    private let storage = Storage.storage(url: "gs://rushday_bucket")
    private let maxImageSize: Int64 = 10 * 1024 * 1024 // 10MB

    // MARK: - Upload Image

    func uploadImage(data: Data, path: String) async throws -> String {
        let storageRef = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }

    // MARK: - Upload Image with Progress

    func uploadImage(
        data: Data,
        path: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let storageRef = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let uploadTask = storageRef.putData(data, metadata: metadata)

        // Observe progress
        uploadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                progressHandler(percentComplete)
            }
        }

        // Wait for completion
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask.observe(.success) { _ in
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: StorageError.uploadFailed)
                    }
                }
            }

            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: StorageError.uploadFailed)
                }
            }
        }
    }

    // MARK: - Upload UIImage

    func uploadUIImage(_ image: UIImage, path: String, compressionQuality: CGFloat = 0.8) async throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw StorageError.invalidImageData
        }
        return try await uploadImage(data: data, path: path)
    }

    // MARK: - Download Image

    func downloadImage(path: String) async throws -> Data {
        let storageRef = storage.reference().child(path)
        return try await storageRef.data(maxSize: maxImageSize)
    }

    // MARK: - Download UIImage

    func downloadUIImage(path: String) async throws -> UIImage {
        let data = try await downloadImage(path: path)
        guard let image = UIImage(data: data) else {
            throw StorageError.invalidImageData
        }
        return image
    }

    // MARK: - Download from URL

    func downloadImage(from url: URL) async throws -> Data {
        let storageRef = storage.reference(forURL: url.absoluteString)
        return try await storageRef.data(maxSize: maxImageSize)
    }

    // MARK: - Get Download URL

    func getDownloadURL(path: String) async throws -> URL {
        let storageRef = storage.reference().child(path)
        return try await storageRef.downloadURL()
    }

    // MARK: - Delete File

    func deleteFile(path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }

    // MARK: - Delete Multiple Files

    func deleteFiles(paths: [String]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for path in paths {
                group.addTask {
                    try await self.deleteFile(path: path)
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Check if File Exists

    func fileExists(path: String) async -> Bool {
        let storageRef = storage.reference().child(path)
        do {
            _ = try await storageRef.getMetadata()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Get File Metadata

    func getMetadata(path: String) async throws -> StorageMetadata {
        let storageRef = storage.reference().child(path)
        return try await storageRef.getMetadata()
    }

    // MARK: - Helper Methods

    func generateImagePath(userId: String, type: ImageType, fileName: String? = nil) -> String {
        let name = fileName ?? UUID().uuidString
        return "\(type.folder)/\(userId)/\(name).jpg"
    }
}

// MARK: - Image Type
enum ImageType {
    case eventCover
    case userAvatar
    case receipt
    case attachment

    var folder: String {
        switch self {
        case .eventCover: return "events/covers"
        case .userAvatar: return "users/avatars"
        case .receipt: return "expenses/receipts"
        case .attachment: return "attachments"
        }
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case uploadFailed
    case downloadFailed
    case fileNotFound
    case invalidImageData
    case fileTooLarge
    case permissionDenied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        case .fileNotFound:
            return "File not found"
        case .invalidImageData:
            return "Invalid image data"
        case .fileTooLarge:
            return "File is too large"
        case .permissionDenied:
            return "Permission denied"
        case .unknown(let message):
            return message
        }
    }
}
