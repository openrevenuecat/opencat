import Foundation
import StoreKit

// MARK: - Product Offering

/// Product offering returned by the OpenCat server.
struct ProductOffering: Codable {
    let storeProductId: String
    let productType: String
    let displayName: String
    let description: String?
    let priceMicros: Int64
    let currency: String
    let subscriptionPeriod: String?
    let trialPeriod: String?
    let entitlements: [String]

    /// StoreKit Product, attached after fetching from StoreKit (nil if StoreKit unavailable)
    var storeProduct: Product?

    enum CodingKeys: String, CodingKey {
        case storeProductId, productType, displayName, description
        case priceMicros, currency, subscriptionPeriod, trialPeriod, entitlements
    }

    /// Price as Decimal (from micros)
    var price: Decimal {
        Decimal(priceMicros) / 1_000_000
    }

    /// Formatted price string
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

struct OfferingsResponse: Codable {
    let offerings: [ProductOffering]
}

// MARK: - Backend Connector

/// HTTP client for communicating with the OpenCat server in server mode.
actor BackendConnector {
    private let serverUrl: URL
    private let apiKey: String
    private let session: URLSession

    init(serverUrl: URL, apiKey: String) {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }

    /// Post a JWS transaction to the server for verification.
    func postTransaction(
        appUserId: String,
        productId: String,
        jwsRepresentation: String
    ) async throws -> CustomerInfo {
        let url = serverUrl.appendingPathComponent("/v1/receipts")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app_user_id": appUserId,
            "product_id": productId,
            "platform": "apple",
            "jws_representation": jwsRepresentation
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder.openCat.decode(CustomerInfo.self, from: data)
    }

    /// Fetch customer info from the server.
    func getCustomerInfo(appUserId: String) async throws -> CustomerInfo {
        let url = serverUrl.appendingPathComponent("/v1/customers/\(appUserId)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder.openCat.decode(CustomerInfo.self, from: data)
    }

    /// Fetch product offerings from the OpenCat server.
    func getOfferings(appId: String) async throws -> [ProductOffering] {
        let url = serverUrl.appendingPathComponent("/v1/apps/\(appId)/offerings")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try JSONDecoder.openCat.decode(OfferingsResponse.self, from: data)
        return decoded.offerings
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCatError.networkError("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenCatError.networkError("Server returned status \(httpResponse.statusCode)")
        }
    }
}

private extension JSONDecoder {
    static let openCat: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
