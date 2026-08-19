//
//  ProfileService.swift
//  transium
//

import Foundation

public protocol ProfileServiceProtocol: Sendable {
    /// Get the caller's profile by user ID.
    func getProfile(userId: String) async throws -> Profile
    
    /// Update the caller's profile name.
    func updateProfile(userId: String, firstName: String?, lastName: String?) async throws -> Profile
    
    /// Upload the caller's avatar photo.
    func uploadAvatar(imageData: Data, filename: String, mimeType: String) async throws -> Profile
    
    /// Remove the caller's avatar photo.
    func deleteAvatar() async throws
}

public final class ProfileService: ProfileServiceProtocol, Sendable {
    public static let shared = ProfileService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func getProfile(userId: String) async throws -> Profile {
        let response: ProfileResponse = try await apiClient.request(
            path: "/private/profile/\(userId)",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.profile
    }

    public func updateProfile(userId: String, firstName: String?, lastName: String?) async throws -> Profile {
        let body = UpdateProfileRequest(firstName: firstName, lastName: lastName)
        let response: ProfileResponse = try await apiClient.request(
            path: "/private/profile/\(userId)",
            method: .patch,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
        return response.profile
    }

    public func uploadAvatar(imageData: Data, filename: String = "avatar.jpg", mimeType: String = "image/jpeg") async throws -> Profile {
        var multipart = MultipartFormData()
        multipart.appendFile(
            fieldName: "file",
            fileName: filename,
            mimeType: mimeType,
            fileData: imageData
        )
        let response: ProfileResponse = try await apiClient.upload(
            path: "/private/profile/media",
            multipart: multipart,
            requiresAuth: true
        )
        return response.profile
    }

    public func deleteAvatar() async throws {
        try await apiClient.requestVoid(
            path: "/private/profile/media",
            method: .delete,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
    }
}
