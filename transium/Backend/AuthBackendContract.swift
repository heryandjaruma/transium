//
//  AuthBackendContract.swift
//  transium
//

import Foundation

protocol AuthBackend: Sendable {
    // MARK: Important Flow - Verify Apple On The Server

    func verifyAppleSignIn(_ credential: AppleSignInCredential) async throws -> AuthSession

    // MARK: Important Flow - Private Profile Access

    func fetchPrivateProfile(accessToken: String) async throws -> BackendProfile
    func upsertPrivateProfile(_ profile: BackendProfile, accessToken: String) async throws -> BackendProfile
    func signOut(accessToken: String) async throws
    func deleteAccount(accessToken: String) async throws
}

struct AuthSession: Codable, Equatable, Sendable {
    let userID: String
    let accessToken: String
    let refreshToken: String?
    let profile: BackendProfile
}

struct BackendProfile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var firstName: String
    var lastName: String?
    var method: String
    var level: String

    init(
        id: UUID,
        firstName: String,
        lastName: String? = nil,
        method: String = AuthMethod.apple.rawValue,
        level: String = ProfileLevel.standard.rawValue
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.method = method
        self.level = level
    }
}

enum AuthBackendRequirement: String, Codable, CaseIterable, Sendable {
    case verifyAppleIdentityTokenSignature
    case verifyAppleNonce
    case verifyAppleIssuer
    case verifyAppleAudience
    case verifyAppleExpiration
    case exchangeSingleUseAuthorizationCode
    case keepRefreshTokenServerSideOnly
    case requireAuthenticatedUserForProfileRoutes
    case enforceProfileOwnerAccess
    case sanitizeProfileNames
}
