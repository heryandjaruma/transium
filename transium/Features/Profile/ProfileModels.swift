//
//  ProfileModels.swift
//  transium
//

import Foundation

// MARK: - Profile
public struct Profile: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let userId: String
    public let firstName: String
    public let lastName: String?
    public let level: Int
    public let image: String?
    public let email: String

    public init(
        id: String,
        userId: String,
        firstName: String,
        lastName: String? = nil,
        level: Int = 1,
        image: String? = nil,
        email: String
    ) {
        self.id = id
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.level = level
        self.image = image
        self.email = email
    }

    public var fullName: String {
        if let last = lastName, !last.isEmpty {
            return "\(firstName) \(last)"
        }
        return firstName
    }
}

// MARK: - Update Profile Request
public struct UpdateProfileRequest: Codable, Sendable {
    public let firstName: String?
    public let lastName: String?

    public init(firstName: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
    }
}

// MARK: - Response Wrappers
public struct ProfileResponse: Codable, Sendable {
    public let profile: Profile

    public init(profile: Profile) {
        self.profile = profile
    }
}
