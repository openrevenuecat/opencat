import Foundation

// MARK: - Event Cover Models

/// Represents a single cover image
struct EventCoverImage: Identifiable, Hashable {
    let type: String
    let shortName: String
    let fullUrl: String

    var id: String { fullUrl }
}

/// Represents a category of cover images
struct EventCoverType: Identifiable {
    let typeName: String
    var images: [EventCoverImage]

    var id: String { typeName }

    /// Get display title for the cover type
    var displayTitle: String {
        switch typeName {
        case "abstract_covers": return "Abstract"
        case "anniversary": return "Anniversary"
        case "birthday": return "Birthday"
        case "business": return "Business"
        case "collection": return "Collection"
        case "graduation": return "Graduation"
        case "vacation": return "Vacation"
        case "wedding_and_engagement": return "Wedding & Engagement"
        case "recents": return "Recents"
        default: return typeName.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Event Cover Service Protocol

protocol EventCoverServiceProtocol {
    /// Fetches a random cover image URL
    func getRandomCover() async throws -> String

    /// Fetches all cover images organized by type
    func getCoversByType() async throws -> [EventCoverType]
}

// MARK: - Event Cover Service Implementation

final class EventCoverService: EventCoverServiceProtocol {
    static let shared = EventCoverService()

    // Media source URL - matches Flutter's AppConfig.appMediaSource
    // Production: rushday_bucket, Dev: rushday_dev_bucket
    private let mediaSource = "https://storage.googleapis.com/rushday_bucket"
    private let eventCoversPath = "event_covers"
    private let abstractCoversPath = "abstract_covers"

    private init() {}

    /// Fetches a random cover image from abstract covers folder
    func getRandomCover() async throws -> String {
        let requestUrl = "\(mediaSource)?prefix=\(eventCoversPath)/\(abstractCoversPath)/"

        guard let url = URL(string: requestUrl) else {
            throw EventCoverError.invalidUrl
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EventCoverError.fetchFailed
        }

        // Parse XML response
        let parser = CoverXMLParser(data: data)
        let keys = parser.parse()

        // Filter for abstract covers
        let abstractCovers = keys.filter { key in
            let prefix = "\(eventCoversPath)/\(abstractCoversPath)/"
            return key.hasPrefix(prefix) && key.count > prefix.count && !key.hasSuffix("/")
        }

        guard !abstractCovers.isEmpty else {
            throw EventCoverError.noCoversFound
        }

        // Return random cover
        let randomIndex = Int.random(in: 0..<abstractCovers.count)
        return "\(mediaSource)/\(abstractCovers[randomIndex])"
    }

    /// Fetches all cover images organized by type
    func getCoversByType() async throws -> [EventCoverType] {
        let requestUrl = "\(mediaSource)?prefix=\(eventCoversPath)/"

        guard let url = URL(string: requestUrl) else {
            throw EventCoverError.invalidUrl
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventCoverError.fetchFailed
            }

            guard httpResponse.statusCode == 200 else {
                throw EventCoverError.fetchFailed
            }

            // Parse XML response
            let parser = CoverXMLParser(data: data)
            let keys = parser.parse()

            // Group images by type
            var coversByType: [String: [EventCoverImage]] = [:]

            for key in keys {
                let prefix = "\(eventCoversPath)/"

                // Skip root folder entries
                guard key.hasPrefix(prefix),
                      key.count > prefix.count else {
                    continue
                }

                // Get path after event_covers/
                let relativePath = String(key.dropFirst(prefix.count))

                // Check if it's in a subfolder
                guard relativePath.contains("/") else { continue }

                let parts = relativePath.split(separator: "/")
                guard parts.count >= 2 else { continue }

                let typeName = String(parts[0])
                let fileName = String(parts.last ?? "")

                // Skip folder entries
                guard !fileName.isEmpty, fileName != typeName else { continue }

                // Create cover image
                let coverImage = EventCoverImage(
                    type: typeName,
                    shortName: fileName,
                    fullUrl: "\(mediaSource)/\(key)"
                )

                // Add to dictionary
                if coversByType[typeName] != nil {
                    coversByType[typeName]?.append(coverImage)
                } else {
                    coversByType[typeName] = [coverImage]
                }
            }

            // Convert to array of EventCoverType
            return coversByType.map { typeName, images in
                EventCoverType(typeName: typeName, images: images)
            }.sorted { $0.typeName < $1.typeName }

        } catch let error as EventCoverError {
            throw error
        } catch {
            throw EventCoverError.fetchFailed
        }
    }

    /// Get default cover URL (fallback)
    var defaultCoverUrl: String {
        "\(mediaSource)/\(eventCoversPath)/\(abstractCoversPath)/background1.jpg"
    }
}

// MARK: - Errors

enum EventCoverError: LocalizedError {
    case invalidUrl
    case fetchFailed
    case noCoversFound
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid cover service URL"
        case .fetchFailed:
            return "Failed to fetch covers"
        case .noCoversFound:
            return "No covers found"
        case .parseFailed:
            return "Failed to parse cover data"
        }
    }
}

// MARK: - Recent Covers Storage

/// Manages recently used cover images in UserDefaults
final class RecentCoversStorage {
    static let shared = RecentCoversStorage()

    private let storageKey = "recent_cover_urls"
    private let maxRecentCovers = 10

    private init() {}

    /// Get all recent cover URLs
    var recentCovers: [String] {
        UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    /// Add a cover URL to recents (most recent first)
    func addCover(_ url: String) {
        var covers = recentCovers

        // Remove if already exists (to move to front)
        covers.removeAll { $0 == url }

        // Insert at beginning
        covers.insert(url, at: 0)

        // Limit to max count
        if covers.count > maxRecentCovers {
            covers = Array(covers.prefix(maxRecentCovers))
        }

        UserDefaults.standard.set(covers, forKey: storageKey)
    }

    /// Clear all recent covers
    func clearRecents() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - XML Parser for Google Cloud Storage response

private class CoverXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var keys: [String] = []
    private var currentElement: String = ""
    private var currentValue: String = ""

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() -> [String] {
        parser.parse()
        return keys
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Key" {
            keys.append(currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
