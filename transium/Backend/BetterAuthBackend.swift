//
//  BetterAuthBackend.swift
//  transium
//

import Foundation

/// Client for Better Auth endpoints exposed by `transium-api`.
/// Authentication uses bearer tokens instead of cookies.
nonisolated struct BetterAuthBackend: AuthBackend {
    let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL = APIConfiguration.authBaseURL, urlSession: URLSession? = nil) {
        self.baseURL = baseURL
        self.urlSession = urlSession ?? Self.makeCookielessSession()
    }

    /// Keep authentication bearer-token only.
    private static func makeCookielessSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil

        return URLSession(configuration: configuration)
    }

    // Send Apple's identity token to Better Auth for server-side verification.
    func verifyAppleSignIn(_ credential: AppleSignInCredential) async throws -> AuthSession {
        // Apple only provides the user's name on the first authorization.
        let name: SignInSocialRequest.IDToken.User.Name? =
            if credential.firstName == nil, credential.lastName == nil {
                nil
            } else {
                .init(firstName: credential.firstName, lastName: credential.lastName)
            }

        let body = SignInSocialRequest(
            provider: AuthMethod.apple.rawValue,
            idToken: .init(
                token: credential.identityToken,
                nonce: credential.rawNonce,
                user: .init(name: name, email: credential.email)
            )
        )

        let (data, response) = try await perform(
            path: "sign-in/social",
            method: "POST",
            body: body
        )

        let value: SignInSocialResponse = try decode(from: data)

        // Better Auth returns the session token in the body or bearer header.
        let headerToken = response.value(forHTTPHeaderField: "set-auth-token")

        guard let accessToken = value.token ?? headerToken, !accessToken.isEmpty else {
            throw BackendError.missingSessionToken
        }

        return AuthSession(
            userID: value.user.id,
            accessToken: accessToken,
            profile: value.user.backendProfile
        )
    }

    // Fetch the currently authenticated user's profile.
    func fetchPrivateProfile(accessToken: String) async throws -> BackendProfile {
        let (data, _) = try await perform(
            path: "get-session",
            method: "GET",
            body: nil,
            accessToken: accessToken
        )

        // Better Auth may return `null` when the session is no longer valid.
        guard !isNullBody(data) else {
            throw BackendError.unauthorized(nil)
        }

        let value: GetSessionResponse = try decode(from: data)

        return value.user.backendProfile
    }

    func upsertPrivateProfile(_ profile: BackendProfile, accessToken: String) async throws -> BackendProfile {
        let fullName = [profile.firstName, profile.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        _ = try await perform(
            path: "update-user",
            method: "POST",
            body: UpdateUserRequest(name: fullName),
            accessToken: accessToken
        )

        return try await fetchPrivateProfile(accessToken: accessToken)
    }

    func signOut(accessToken: String) async throws {
        _ = try await perform(
            path: "sign-out",
            method: "POST",
            body: EmptyRequest(),
            accessToken: accessToken
        )
    }

    func deleteAccount(accessToken: String) async throws {
        // Account deletion is not enabled on the backend yet.
        throw BackendError.unsupported(
            "Account deletion is not enabled on the server yet."
        )
    }

    // MARK: - Transport

    private func perform(
        path: String,
        method: String,
        body: (any Encodable)?,
        accessToken: String? = nil
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder().decode(APIErrorResponse.self, from: data).message

            throw httpResponse.statusCode == 401 || httpResponse.statusCode == 403
                ? BackendError.unauthorized(message)
                : BackendError.requestFailed(status: httpResponse.statusCode, message: message)
        }

        return (data, httpResponse)
    }

    private func decode<Value: Decodable>(from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }

    private func isNullBody(_ data: Data) -> Bool {
        let body = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return body.isEmpty || body == "null"
    }
}

// MARK: - Wire Format

nonisolated private struct EmptyRequest: Encodable {}

nonisolated private struct SignInSocialRequest: Encodable {
    let provider: String
    let idToken: IDToken

    struct IDToken: Encodable {
        // Apple's signed identity token.
        let token: String
        // Raw nonce used to validate the Apple sign-in request.
        let nonce: String
        let user: User?

        struct User: Encodable {
            let name: Name?
            let email: String?

            struct Name: Encodable {
                let firstName: String?
                let lastName: String?
            }
        }
    }
}

nonisolated private struct SignInSocialResponse: Decodable {
    let token: String?
    let user: BetterAuthUser
}

nonisolated private struct GetSessionResponse: Decodable {
    let user: BetterAuthUser
}

nonisolated private struct UpdateUserRequest: Encodable {
    let name: String
}

nonisolated private struct APIErrorResponse: Decodable {
    let message: String?
    let code: String?
}

nonisolated private struct BetterAuthUser: Decodable {
    let id: String
    let name: String
    let email: String
    let image: String?

    // Convert Better Auth's single `name` field into the app profile model.
    var backendProfile: BackendProfile {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map(String.init)

        return BackendProfile(
            id: id,
            firstName: parts.first ?? "Transium",
            lastName: parts.count > 1 ? parts[1] : nil
        )
    }
}
