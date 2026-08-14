//
//  AuthStore.swift
//  transium
//

import Foundation
import SwiftData

@MainActor
struct AuthStore {
    let modelContext: ModelContext

    // MARK: Important Flow - Persist Successful Apple Sign-In

    @discardableResult
    func upsertLocalProfile(
        from credential: AppleSignInCredential,
        remoteUserID: String? = nil
    ) throws -> LocalProfile {
        if let identity = try localIdentity(forAppleUserIdentifier: credential.appleUserIdentifier) {
            identity.markAuthenticated(with: credential, remoteUserID: remoteUserID)

            if let profile = try localProfile(id: identity.profileID) {
                if profile.firstName.isEmpty || credential.firstName != nil || credential.lastName != nil {
                    profile.apply(credential.profileSeed)
                }

                try modelContext.save()
                return profile
            }
        }

        let profile = LocalProfile(
            firstName: credential.profileSeed.firstName,
            lastName: credential.profileSeed.lastName,
            method: credential.profileSeed.method,
            level: credential.profileSeed.level
        )
        let identity = LocalAuthIdentity(
            appleUserIdentifier: credential.appleUserIdentifier,
            profileID: profile.id,
            remoteUserID: remoteUserID,
            email: credential.email,
            realUserStatus: credential.realUserStatus.rawValue
        )

        modelContext.insert(profile)
        modelContext.insert(identity)
        try modelContext.save()

        return profile
    }

    // MARK: Important Flow - Clear Revoked Or Deleted Session

    func deleteLocalIdentityAndProfile(_ identity: LocalAuthIdentity) throws {
        if let profile = try localProfile(id: identity.profileID) {
            modelContext.delete(profile)
        }

        modelContext.delete(identity)
        try modelContext.save()
    }

    // MARK: Important Flow - Revalidate Stored Apple Session

    func refreshStoredAppleCredentialState(using appleSignInService: AppleSignInService) async throws {
        guard let identity = try latestLocalIdentity() else {
            return
        }

        let credentialState = try await appleSignInService.credentialState(
            forAppleUserIdentifier: identity.appleUserIdentifier
        )
        identity.updateCredentialState(credentialState)

        do {
            try credentialState.validateForActiveSession()
            try modelContext.save()
        } catch let authError as AuthError
            where authError == .credentialRevoked || authError == .credentialNotFound || authError == .credentialTransferred {
            try deleteLocalIdentityAndProfile(identity)
            throw authError
        }
    }

    // MARK: - Queries

    func latestLocalIdentity() throws -> LocalAuthIdentity? {
        var descriptor = FetchDescriptor<LocalAuthIdentity>(
            sortBy: [SortDescriptor(\.lastAuthenticatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    func localIdentity(forAppleUserIdentifier appleUserIdentifier: String) throws -> LocalAuthIdentity? {
        var descriptor = FetchDescriptor<LocalAuthIdentity>(
            predicate: #Predicate { $0.appleUserIdentifier == appleUserIdentifier }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    func localProfile(id: UUID) throws -> LocalProfile? {
        var descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }
}
