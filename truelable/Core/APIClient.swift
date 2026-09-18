import Foundation

enum APIError: LocalizedError {
    case notFound
    case offline
    case unauthorized
    case rateLimited
    case server(Int)
    case invalid

    var errorDescription: String? {
        switch self {
        case .notFound: "Not in the catalogue yet"
        case .offline: "Couldn't reach TrueLabel. Check your connection and try again."
        case .unauthorized: "This device couldn't be recognised. Try again in a moment."
        case .rateLimited: "That's a lot of requests. Give it a minute and try again."
        case .server(let code): "The server had a problem (HTTP \(code)). Try again in a moment."
        case .invalid: "That response didn't make sense. Try again."
        }
    }
}

struct DeviceRegistration: Decodable, Sendable {
    var deviceId: String
    var token: String
}

enum API {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    static var country: String { Locale.current.region?.identifier ?? "IN" }

    static func product(barcode: String) async throws -> Product {
        let env: Envelope<Product> = try await get("api/v1/products/search", ["barcode": barcode, "country": country])
        guard let p = env.data else { throw APIError.notFound }
        return p
    }

    static func search(_ q: String, limit: Int = 20) async throws -> [ProductCard] {
        let env: Envelope<[ProductCard]> = try await get("api/v1/products/query", ["q": q, "country": country, "limit": "\(limit)"])
        return env.data ?? []
    }

    static func trending(limit: Int = 10) async throws -> [ProductCard] {
        let env: Envelope<[ProductCard]> = try await get("api/v1/products/trending", ["country": country, "limit": "\(limit)"])
        return env.data ?? []
    }

    static func alternatives(barcode: String, sortBy: String, limit: Int = 3) async throws -> [ProductCard] {
        let env: Envelope<[ProductCard]> = try await get("api/v1/products/alternatives", [
            "barcode": barcode, "country": country, "sort_by": sortBy, "limit": "\(limit)"
        ])
        return env.data ?? []
    }

    static func verify(barcode: String) async throws -> Product {
        struct Body: Encodable { var barcode: String; var country: String }
        let env: Envelope<Product> = try await post("api/v1/products/verify", Body(barcode: barcode, country: country))
        guard let p = env.data else { throw APIError.invalid }
        return p
    }

    static func needsVerification(limit: Int = 12) async throws -> [Candidate] {
        let env: Envelope<[Candidate]> = try await get(
            "api/v1/products/needs-verification",
            ["country": country, "limit": "\(limit)"]
        )
        return env.data ?? []
    }

    struct LabelSubmission: Encodable {
        var barcode: String
        var country: String
        var extractedText: String
        var reviewedIngredients: String
        var reviewedAllergens: [String]
        var productName: String?
        var brand: String?
        var nutrition: Nutrition?
    }

    static func registerDevice() async throws -> DeviceRegistration {
        let env: Envelope<DeviceRegistration> = try await send("api/v1/auth/device", method: "POST", authenticated: false)
        guard let registration = env.data else { throw APIError.invalid }
        return registration
    }

    static func profile() async throws -> Profile {
        let env: Envelope<Profile> = try await get("api/v1/me/profile", ["country": country])
        guard let p = env.data else { throw APIError.invalid }
        return p
    }

    static func updateProfile(dietaryPreferences: [String]? = nil, displayName: String? = nil) async throws -> Profile {
        struct Body: Encodable {
            var country: String
            var dietaryPreferences: [String]?
            var displayName: String?
        }
        let env: Envelope<Profile> = try await put(
            "api/v1/me/profile",
            Body(country: country, dietaryPreferences: dietaryPreferences, displayName: displayName)
        )
        guard let p = env.data else { throw APIError.invalid }
        return p
    }

    static func stats() async throws -> ContributionStats {
        let env: Envelope<ContributionStats> = try await get("api/v1/me/stats", [:])
        guard let s = env.data else { throw APIError.invalid }
        return s
    }

    static func subscription() async throws -> Subscription {
        let env: Envelope<Subscription> = try await get("api/v1/me/subscription", [:])
        guard let s = env.data else { throw APIError.invalid }
        return s
    }

    static func activatePlus() async throws -> Subscription {
        let env: Envelope<Subscription> = try await send("api/v1/me/subscription", method: "POST")
        guard let s = env.data else { throw APIError.invalid }
        return s
    }

    static func cancelPlus() async throws -> Subscription {
        let env: Envelope<Subscription> = try await send("api/v1/me/subscription", method: "DELETE")
        guard let s = env.data else { throw APIError.invalid }
        return s
    }

    static func linkApple(identityToken: String, displayName: String?) async throws -> Profile {
        struct Body: Encodable { var identityToken: String; var displayName: String? }
        let env: Envelope<Profile> = try await post("api/v1/me/link",
                                                    Body(identityToken: identityToken, displayName: displayName))
        guard let p = env.data else { throw APIError.invalid }
        return p
    }

    static func unlinkApple() async throws -> Profile {
        let env: Envelope<Profile> = try await send("api/v1/me/unlink", method: "POST")
        guard let p = env.data else { throw APIError.invalid }
        return p
    }

    static func deleteAccount() async throws {
        struct Reply: Decodable { var deleted: Bool? }
        let _: Envelope<Reply> = try await send("api/v1/me/account", method: "DELETE")
    }

    static func submitLabel(_ submission: LabelSubmission) async throws {
        struct Reply: Decodable { var guessedName: String? }
        let _: Reply = try await post("api/v1/ocr/submit", submission)
    }

    struct CrashReportSubmission: Encodable {
        var platform = "ios"
        var title: String
        var description: String?
        var stackTrace: String?
        var appVersion: String?
        var osVersion: String?
        var deviceModel: String?
        var severity = "critical"
        var deviceId: String?
    }

    static func submitCrashReport(_ submission: CrashReportSubmission) async throws {
        struct Reply: Decodable {}
        let _: Envelope<Reply> = try await post("api/v1/crash-reports", submission)
    }

    private struct Envelope<T: Decodable>: Decodable {
        var status: String
        var data: T?
    }

    private static func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var components = URLComponents(url: APIEnvironment.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty
            ? nil
            : query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await run(URLRequest(url: components.url!))
    }

    private static func put<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        var request = URLRequest(url: APIEnvironment.baseURL.appending(path: path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await run(request)
    }

    private static func send<T: Decodable>(_ path: String, method: String, authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: APIEnvironment.baseURL.appending(path: path))
        request.httpMethod = method
        return try await run(request, authenticated: authenticated)
    }

    private static func post<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        var request = URLRequest(url: APIEnvironment.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await run(request)
    }

    private static func run<T: Decodable>(
        _ request: URLRequest,
        authenticated: Bool = true,
        retryingAfterReauth: Bool = true
    ) async throws -> T {
        var request = request
        if authenticated {
            request.setValue("Bearer \(try await DeviceAuth.shared.token())", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {

            throw APIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalid }
        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(T.self, from: data) } catch { throw APIError.invalid }
        case 401 where authenticated && retryingAfterReauth:

            await DeviceAuth.shared.forget()
            return try await run(request, authenticated: true, retryingAfterReauth: false)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(http.statusCode)
        }
    }
}

struct ProductCard: Decodable, Identifiable, Hashable, Sendable {
    var id: String { barcode }
    var barcode: String
    var productName: String
    var brand: String?
    var imageUrl: String?
    var nutriscoreGrade: String?
    var novaGroup: Int?
    var verified: Bool
    var energyKcal: Double?
    var sugar: Double?
    var sodium: Double?
    var sortValue: Double?

    var imageURL: URL? { imageUrl.flatMap(URL.init(string:)) }
}

struct ContributionStats: Decodable, Sendable {
    var confirmations: Int
    var contributions: Int
    var helpedVerify: Int
}

struct Profile: Decodable, Sendable {
    var country: String
    var dietaryPreferences: [String]
    var subscription: Subscription
    var identity: Identity
}

struct Identity: Decodable, Sendable {
    var signedIn: Bool
    var provider: String?

    var email: String?
    var displayName: String?
}

struct Subscription: Decodable, Sendable {
    var tier: String
    var active: Bool
    var source: String?

    var isComplimentary: Bool { source == "complimentary" }
}

struct Candidate: Decodable, Identifiable, Hashable, Sendable {
    var id: String { barcode }
    var barcode: String
    var productName: String
    var brand: String?
    var imageUrl: String?
    var nutriscoreGrade: String?
    var energyKcal: Double?
    var sugar: Double?
    var sodium: Double?
    var verificationCount: Int

    var imageURL: URL? { imageUrl.flatMap(URL.init(string:)) }
}
