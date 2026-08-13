//
//  ProfileModel.swift
//  transium
//

import Foundation
import SwiftData

// MARK: - Profile Reference Data

enum ProfileLevel: String, Codable, CaseIterable, Sendable {
    case standard
}

struct ProfileSeed: Codable, Equatable, Sendable {
    var firstName: String
    var lastName: String?
    var method: String
    var level: String
}

// MARK: - Local Device Profile

@Model
final class LocalProfile {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String?
    var method: String
    var level: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String? = nil,
        method: String = AuthMethod.apple.rawValue,
        level: String = ProfileLevel.standard.rawValue,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.method = method
        self.level = level
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Important Flow - Keep Apple Name Updates Conservative

    func apply(_ seed: ProfileSeed) {
        firstName = seed.firstName
        lastName = seed.lastName
        method = seed.method
        level = seed.level
        updatedAt = .now
    }
}
