//
//  APIClient.swift
//  transium
//

import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
    case put = "PUT"
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]?,
        body: (any Encodable)?,
        requiresAuth: Bool
    ) async throws -> T

    func requestVoid(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]?,
        body: (any Encodable)?,
        requiresAuth: Bool
    ) async throws

    func upload<T: Decodable>(
        path: String,
        multipart: MultipartFormData,
        requiresAuth: Bool
    ) async throws -> T
}

public final class APIClient: APIClientProtocol, @unchecked Sendable {
    public static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    public init(
        baseURL: URL = APIConfiguration.apiBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    public func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth
        )

        let (data, response) = try await session.data(for: request)
        try validateResponse(response: response, data: data)

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw TransiumAPIError.decodingError(error)
        }
    }

    public func requestVoid(
        path: String,
        method: HTTPMethod = .delete,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true
    ) async throws {
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth
        )

        let (data, response) = try await session.data(for: request)
        try validateResponse(response: response, data: data)
    }

    public func upload<T: Decodable>(
        path: String,
        multipart: MultipartFormData,
        requiresAuth: Bool = true
    ) async throws -> T {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appending(path: relativePath)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = SessionTokenStore.read(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let bodyData = multipart.finalize()
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try validateResponse(response: response, data: data)

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw TransiumAPIError.decodingError(error)
        }
    }

    // MARK: - Private Helpers

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]?,
        body: (any Encodable)?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let targetURL = baseURL.appending(path: relativePath)
        guard var components = URLComponents(url: targetURL, resolvingAgainstBaseURL: true) else {
            throw TransiumAPIError.invalidURL
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw TransiumAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if requiresAuth, let token = SessionTokenStore.read(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try jsonEncoder.encode(body)
            } catch {
                throw TransiumAPIError.invalidRequest("Failed to encode request body.")
            }
        }

        return request
    }

    private func validateResponse(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransiumAPIError.unknown
        }

        let statusCode = httpResponse.statusCode
        if (200...299).contains(statusCode) {
            return
        }

        let serverMessage = parseErrorMessage(from: data)

        switch statusCode {
        case 400:
            throw TransiumAPIError.invalidRequest(serverMessage ?? "Invalid arguments")
        case 401:
            throw TransiumAPIError.unauthorized
        case 403:
            throw TransiumAPIError.forbidden
        case 404:
            throw TransiumAPIError.notFound(serverMessage ?? "Resource not found")
        case 409:
            throw TransiumAPIError.conflict(serverMessage ?? "Conflict", data)
        case 422:
            throw TransiumAPIError.unprocessableEntity(serverMessage ?? "Unprocessable entity")
        case 503:
            throw TransiumAPIError.serviceUnavailable(serverMessage ?? "Service unavailable")
        default:
            throw TransiumAPIError.serverError(statusCode: statusCode, message: serverMessage ?? "HTTP \(statusCode)")
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct ErrorWrapper: Decodable {
            let error: String?
            let message: String?
        }
        if let wrapper = try? jsonDecoder.decode(ErrorWrapper.self, from: data) {
            return wrapper.error ?? wrapper.message
        }
        return String(data: data, encoding: .utf8)
    }
}
