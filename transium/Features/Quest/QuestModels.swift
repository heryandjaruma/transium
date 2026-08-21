//
//  QuestModels.swift
//  transium
//

import Foundation

// MARK: - Quest
public nonisolated struct Quest: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
    }
}

// MARK: - QuestWithUserStatus
public nonisolated struct QuestWithUserStatus: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]
    public let userQuestStatus: String?

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = [],
        userQuestStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
        self.userQuestStatus = userQuestStatus
    }
}

// MARK: - QuestBadgeEntry
public nonisolated struct QuestBadgeEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let questId: String?
    public let badgeId: String
    public let badgeName: String
    public let badgeCategory: String
    public let badgeType: String
    public let badgeImageUrl: String?

    public init(
        id: String,
        questId: String? = nil,
        badgeId: String,
        badgeName: String,
        badgeCategory: String,
        badgeType: String,
        badgeImageUrl: String? = nil
    ) {
        self.id = id
        self.questId = questId
        self.badgeId = badgeId
        self.badgeName = badgeName
        self.badgeCategory = badgeCategory
        self.badgeType = badgeType
        self.badgeImageUrl = badgeImageUrl
    }
}

// MARK: - BadgeActionStep
public nonisolated struct BadgeActionStep: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let badgeId: String
    public let actionId: String
    public let actionName: String
    public let type: String?
    public let sequence: Int
    public let lat: Double?
    public let lng: Double?
    public let instruction: String?

    public init(
        id: String,
        badgeId: String,
        actionId: String,
        actionName: String,
        type: String? = nil,
        sequence: Int,
        lat: Double? = nil,
        lng: Double? = nil,
        instruction: String? = nil
    ) {
        self.id = id
        self.badgeId = badgeId
        self.actionId = actionId
        self.actionName = actionName
        self.type = type
        self.sequence = sequence
        self.lat = lat
        self.lng = lng
        self.instruction = instruction
    }
}

// MARK: - QuestBadgeWithSteps
public nonisolated struct QuestBadgeWithSteps: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let badgeId: String
    public let badgeName: String
    public let badgeCategory: String
    public let badgeType: String
    public let badgeImageUrl: String?
    public let steps: [BadgeActionStep]

    public init(
        id: String,
        badgeId: String,
        badgeName: String,
        badgeCategory: String,
        badgeType: String,
        badgeImageUrl: String? = nil,
        steps: [BadgeActionStep] = []
    ) {
        self.id = id
        self.badgeId = badgeId
        self.badgeName = badgeName
        self.badgeCategory = badgeCategory
        self.badgeType = badgeType
        self.badgeImageUrl = badgeImageUrl
        self.steps = steps
    }
}

// MARK: - QuestDetail
public nonisolated struct QuestDetail: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]
    public let badges: [QuestBadgeWithSteps]
    public let origin: LatLng?
    public let destination: LatLng?

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = [],
        badges: [QuestBadgeWithSteps] = [],
        origin: LatLng? = nil,
        destination: LatLng? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
        self.badges = badges
        self.origin = origin
        self.destination = destination
    }
}

// MARK: - QuestWithBadges
public nonisolated struct QuestWithBadges: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]
    public let badges: [QuestBadgeEntry]

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = [],
        badges: [QuestBadgeEntry] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
        self.badges = badges
    }
}

// MARK: - QuestWithDistance
public nonisolated struct QuestWithDistance: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]
    public let distanceMeters: Double?

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = [],
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
        self.distanceMeters = distanceMeters
    }
}

// MARK: - QuestWithBadgesAndDistance
public nonisolated struct QuestWithBadgesAndDistance: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let xp: Int?
    public let label: String?
    public let thumbnails: [MediaAsset]
    public let badges: [QuestBadgeEntry]
    public let distanceMeters: Double?

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        xp: Int? = nil,
        label: String? = nil,
        thumbnails: [MediaAsset] = [],
        badges: [QuestBadgeEntry] = [],
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.xp = xp
        self.label = label
        self.thumbnails = thumbnails
        self.badges = badges
        self.distanceMeters = distanceMeters
    }
}

// MARK: - KelurahanQuestsGroup
public nonisolated struct KelurahanQuestsGroup: Codable, Sendable, Equatable {
    public let kelurahan: Kelurahan
    public let quests: [Quest]

    public init(kelurahan: Kelurahan, quests: [Quest]) {
        self.kelurahan = kelurahan
        self.quests = quests
    }
}

// MARK: - Response Wrappers
nonisolated struct QuestListResponse: Codable {
    let quests: [Quest]
}

nonisolated struct QuestDetailResponse: Codable {
    let quest: QuestDetail
}

nonisolated struct QuestBadgesResponse: Codable {
    let questBadges: [QuestBadgeEntry]
}

nonisolated struct KelurahanQuestGroupsResponse: Codable {
    let groups: [KelurahanQuestsGroup]
}

public nonisolated struct KelurahanDetailQuestsResponse: Codable, Sendable, Equatable {
    public let kelurahan: Kelurahan
    public let quests: [QuestWithBadges]
}
