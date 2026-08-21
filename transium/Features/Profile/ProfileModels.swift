//
//  ProfileModels.swift
//  transium
//

import Foundation

// MARK: - Profile
public nonisolated struct Profile: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let userId: String
    public let firstName: String
    public let lastName: String?
    public let level: Int
    public let image: String?
    // Documented as required by the OpenAPI spec, but POST /private/journey/{id}/complete's
    // embedded `profile` (a leaner projection, not the full GET /private/profile response)
    // omits it in practice — kept optional so decoding doesn't hard-fail on that.
    public let email: String?

    public init(
        id: String,
        userId: String,
        firstName: String,
        lastName: String? = nil,
        level: Int = 1,
        image: String? = nil,
        email: String? = nil
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
/// `firstName` is omitted from the request when nil (leave unchanged); `lastName`
/// is always sent, as an explicit JSON `null` when nil, matching the API's
/// "omit to keep, null to clear" contract for that field.
public nonisolated struct UpdateProfileRequest: Encodable, Sendable {
    public let firstName: String?
    public let lastName: String?

    public init(firstName: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
    }

    private enum CodingKeys: String, CodingKey {
        case firstName, lastName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(firstName, forKey: .firstName)

        if let lastName {
            try container.encode(lastName, forKey: .lastName)
        } else {
            try container.encodeNil(forKey: .lastName)
        }
    }
}

// MARK: - Response Wrappers
public nonisolated struct ProfileResponse: Codable, Sendable {
    public let profile: Profile

    public init(profile: Profile) {
        self.profile = profile
    }
}

/// `POST /private/profile/media` returns just the new avatar URL, not a full `Profile`.
public nonisolated struct AvatarUploadResponse: Codable, Sendable {
    public let image: String

    public init(image: String) {
        self.image = image
    }
}
