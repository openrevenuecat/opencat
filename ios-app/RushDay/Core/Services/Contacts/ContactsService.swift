import Foundation
import Contacts

// MARK: - Contact Model

/// A simplified contact model for use in the app
struct AppContact: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let firstName: String
    let lastName: String
    let email: String?
    let phoneNumber: String?
    let imageData: Data?

    init(from cnContact: CNContact) {
        self.id = cnContact.identifier
        self.firstName = cnContact.givenName
        self.lastName = cnContact.familyName
        self.displayName = CNContactFormatter.string(from: cnContact, style: .fullName) ?? "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
        self.email = cnContact.emailAddresses.first?.value as String?
        self.phoneNumber = cnContact.phoneNumbers.first?.value.stringValue
        self.imageData = cnContact.thumbnailImageData
    }

    /// Returns initials for avatar display
    var initials: String {
        let firstInitial = firstName.first.map { String($0) } ?? ""
        let lastInitial = lastName.first.map { String($0) } ?? ""
        let result = "\(firstInitial)\(lastInitial)".uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Contacts Service Errors

enum ContactsServiceError: LocalizedError {
    case accessDenied
    case accessRestricted
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to contacts was denied. Please enable access in Settings."
        case .accessRestricted:
            return "Access to contacts is restricted on this device."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

// MARK: - Contacts Service Implementation

final class ContactsServiceImpl: ContactsServiceProtocol, @unchecked Sendable {
    private let contactStore = CNContactStore()

    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    func requestAccess() async throws -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized, .limited:
            return true
        case .denied:
            throw ContactsServiceError.accessDenied
        case .restricted:
            throw ContactsServiceError.accessRestricted
        case .notDetermined:
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                return granted
            } catch {
                throw ContactsServiceError.fetchFailed(error)
            }
        @unknown default:
            return false
        }
    }

    func fetchContacts() async throws -> [AppContact] {
        // Ensure we have access
        if !isAuthorized {
            let granted = try await requestAccess()
            guard granted else {
                throw ContactsServiceError.accessDenied
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                do {
                    var contacts: [AppContact] = []
                    let request = CNContactFetchRequest(keysToFetch: self.keysToFetch)
                    request.sortOrder = .givenName

                    try self.contactStore.enumerateContacts(with: request) { cnContact, _ in
                        let contact = AppContact(from: cnContact)
                        // Only include contacts with a name
                        if !contact.displayName.isEmpty {
                            contacts.append(contact)
                        }
                    }

                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: ContactsServiceError.fetchFailed(error))
                }
            }
        }
    }

    func searchContacts(query: String) async throws -> [AppContact] {
        let allContacts = try await fetchContacts()

        guard !query.isEmpty else {
            return allContacts
        }

        let lowercasedQuery = query.lowercased()
        return allContacts.filter { contact in
            contact.displayName.lowercased().contains(lowercasedQuery) ||
            (contact.email?.lowercased().contains(lowercasedQuery) ?? false) ||
            (contact.phoneNumber?.contains(query) ?? false)
        }
    }
}
