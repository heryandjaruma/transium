//
//  AuthModels.swift
//  transium
//

import AuthenticationServices
import Foundation
import SwiftData

// MARK: - Auth Reference Data

enum AuthMethod: String, Codable, CaseIterable, Sendable {
    case apple
}

enum AuthError: Error, LocalizedError, Sendable {
    case invalidAuthorization
    case missingAppleIdentityToken
    case missingAppleAuthorizationCode
    case invalidAppleIdentityTokenEncoding
    case invalidAppleAuthorizationCodeEncoding
    case invalidAppleState
    case credentialRevoked
    case credentialNotFound
    case credentialTransferred
    case unknownCredentialState

    var errorDescription: String? {
        switch self {
        case .invalidAuthorization:
            "The Apple authorization response was not valid."
        case .missingAppleIdentityToken:
            "Apple did not return an identity token."
        case .missingAppleAuthorizationCode:
            "Apple did not return an authorization code."
        case .invalidAppleIdentityTokenEncoding:
            "The Apple identity token could not be decoded."
        case .invalidAppleAuthorizationCodeEncoding:
            "The Apple authorization code could not be decoded."
        case .invalidAppleState:
            "The Apple authorization state did not match this sign-in request."
        case .credentialRevoked:
            "This Apple credential was revoked."
        case .credentialNotFound:
            "This Apple credential was not found."
        case .credentialTransferred:
            "This Apple credential was transferred to another team."
        case .unknownCredentialState:
            "The Apple credential state could not be determined."
        }
    }
}

enum AppleRealUserStatus: String, Codable, Sendable {
    case unsupported
    case unknown
    case likelyReal

    init(_ status: ASUserDetectionStatus) {
        switch status {
        case .unsupported:
            self = .unsupported
        case .unknown:
            self = .unknown
        case .likelyReal:
            self = .likelyReal
        @unknown default:
            self = .unknown
        }
    }
}

enum AppleCredentialState: String, Codable, Sendable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown

    init(_ state: ASAuthorizationAppleIDProvider.CredentialState) {
        switch state {
        case .authorized:
            self = .authorized
        case .revoked:
            self = .revoked
        case .notFound:
            self = .notFound
        case .transferred:
            self = .transferred
        @unknown default:
            self = .unknown
        }
    }

    // Make sure an existing Apple credential can still be used.
    func validateForActiveSession() throws {
        switch self {
        case .authorized:
            return
        case .revoked:
            throw AuthError.credentialRevoked
        case .notFound:
            throw AuthError.credentialNotFound
        case .transferred:
            throw AuthError.credentialTransferred
        case .unknown:
            throw AuthError.unknownCredentialState
        }
    }
}

// MARK: - Apple Sign-In Payload

struct AppleSignInCredential: Codable, Sendable {
    let appleUserIdentifier: String
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
    let state: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let realUserStatus: AppleRealUserStatus
    let receivedAt: Date

    var profileSeed: ProfileSeed {
        ProfileSeed(
            firstName: firstName?.nilIfBlank ?? "Transium",
            lastName: lastName?.nilIfBlank,
            method: AuthMethod.apple.rawValue,
            level: ProfileLevel.standard.rawValue
        )
    }

    // Extract the values returned by Sign in with Apple.
    init(
        credential: ASAuthorizationAppleIDCredential,
        requestContext: AppleSignInRequestContext
    ) throws {
        guard credential.state == requestContext.state else {
            throw AuthError.invalidAppleState
        }

        guard let identityTokenData = credential.identityToken else {
            throw AuthError.missingAppleIdentityToken
        }

        guard let authorizationCodeData = credential.authorizationCode else {
            throw AuthError.missingAppleAuthorizationCode
        }

        guard let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidAppleIdentityTokenEncoding
        }

        guard let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw AuthError.invalidAppleAuthorizationCodeEncoding
        }

        self.appleUserIdentifier = credential.user
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.rawNonce = requestContext.rawNonce
        self.state = credential.state
        self.email = credential.email?.nilIfBlank
        self.firstName = credential.fullName?.givenName?.nilIfBlank
        self.lastName = credential.fullName?.familyName?.nilIfBlank
        self.realUserStatus = AppleRealUserStatus(credential.realUserStatus)
        self.receivedAt = .now
    }
}

// MARK: - Local Device Auth Identity

@Model
final class LocalAuthIdentity {
    @Attribute(.unique) var appleUserIdentifier: String
    var profileID: UUID
    // Better Auth user ID after the first successful server sign-in.
    var remoteUserID: String?
    var method: String
    var email: String?
    var realUserStatus: String
    var credentialState: String
    var createdAt: Date
    var lastAuthenticatedAt: Date
    var lastCredentialStateCheckedAt: Date?

    init(
        appleUserIdentifier: String,
        profileID: UUID,
        remoteUserID: String? = nil,
        method: String = AuthMethod.apple.rawValue,
        email: String? = nil,
        realUserStatus: String = AppleRealUserStatus.unknown.rawValue,
        credentialState: String = AppleCredentialState.authorized.rawValue,
        createdAt: Date = .now,
        lastAuthenticatedAt: Date = .now,
        lastCredentialStateCheckedAt: Date? = nil
    ) {
        self.appleUserIdentifier = appleUserIdentifier
        self.profileID = profileID
        self.remoteUserID = remoteUserID
        self.method = method
        self.email = email
        self.realUserStatus = realUserStatus
        self.credentialState = credentialState
        self.createdAt = createdAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
        self.lastCredentialStateCheckedAt = lastCredentialStateCheckedAt
    }

    // Update locally stored auth information after a successful sign-in.
    func markAuthenticated(with credential: AppleSignInCredential, remoteUserID: String? = nil) {
        email = credential.email ?? email
        self.remoteUserID = remoteUserID ?? self.remoteUserID
        realUserStatus = credential.realUserStatus.rawValue
        credentialState = AppleCredentialState.authorized.rawValue
        lastAuthenticatedAt = .now
    }

    func updateCredentialState(_ state: AppleCredentialState) {
        credentialState = state.rawValue
        lastCredentialStateCheckedAt = .now
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
