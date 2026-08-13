//
//  AppleSignInService.swift
//  transium
//

import AuthenticationServices
import CryptoKit
import Foundation
import Security

struct AppleSignInRequestContext: Sendable {
    let rawNonce: String
    let hashedNonce: String
    let state: String
}

@MainActor
final class AppleSignInService {
    private(set) var requestContext: AppleSignInRequestContext?

    // MARK: Important Flow - Configure Apple Authorization Request

    func configure(_ request: ASAuthorizationAppleIDRequest) throws {
        let context = try makeRequestContext()

        request.requestedScopes = [.fullName, .email]
        request.nonce = context.hashedNonce
        request.state = context.state
        requestContext = context
    }

    // MARK: Important Flow - Convert Apple Authorization To App Credential

    func credential(from authorization: ASAuthorization) throws -> AppleSignInCredential {
        guard
            let requestContext,
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            throw AuthError.invalidAuthorization
        }

        return try AppleSignInCredential(
            credential: appleIDCredential,
            requestContext: requestContext
        )
    }

    func reset() {
        requestContext = nil
    }

    // MARK: Important Flow - Check Existing Apple Credential State

    func credentialState(forAppleUserIdentifier appleUserIdentifier: String) async throws -> AppleCredentialState {
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserIdentifier) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: AppleCredentialState(state))
            }
        }
    }

    // MARK: - Nonce And State

    private func makeRequestContext() throws -> AppleSignInRequestContext {
        let rawNonce = try randomURLSafeString()

        return AppleSignInRequestContext(
            rawNonce: rawNonce,
            hashedNonce: sha256(rawNonce),
            state: try randomURLSafeString()
        )
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private func randomURLSafeString(length: Int = 32) throws -> String {
        precondition(length > 0)

        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: nil
            )
        }

        return String(bytes.map { characters[Int($0) % characters.count] })
    }
}
