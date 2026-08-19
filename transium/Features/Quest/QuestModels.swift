//
//  QuestModels.swift
//  transium
//

import Foundation

// MARK: - Quest
public struct Quest: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let thumbnails: [MediaAsset]

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        thumbnails: [MediaAsset] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.thumbnails = thumbnails
    }
}

// MARK: - QuestBadgeEntry
public struct QuestBadgeEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let badgeId: String
    public let badgeName: String
    public let badgeCategory: String
    public let badgeType: String
    public let badgeImageUrl: String?

    public init(
        id: String,
        badgeId: String,
        badgeName: String,
        badgeCategory: String,
        badgeType: String,
        badgeImageUrl: String? = nil
    ) {
        self.id = id
        self.badgeId = badgeId
        self.badgeName = badgeName
        self.badgeCategory = badgeCategory
        self.badgeType = badgeType
        self.badgeImageUrl = badgeImageUrl
    }
}

// MARK: - BadgeActionStep
public struct BadgeActionStep: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let badgeId: String
    public let actionId: String
    public let actionName: String
    public let actionType: String
    public let sequence: Int
    public let lat: Double?
    public let lng: Double?
    public let instruction: String?

    public init(
        id: String,
        badgeId: String,
        actionId: String,
        actionName: String,
        actionType: String,
        sequence: Int,
        lat: Double? = nil,
        lng: Double? = nil,
        instruction: String? = nil
    ) {
        self.id = id
        self.badgeId = badgeId
        self.actionId = actionId
        self.actionName = actionName
        self.actionType = actionType
        self.sequence = sequence
        self.lat = lat
        self.lng = lng
        self.instruction = instruction
    }
}

// MARK: - QuestBadgeWithSteps
public struct QuestBadgeWithSteps: Codable, Identifiable, Sendable, Equatable {
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
public struct QuestDetail: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let thumbnails: [MediaAsset]
    public let badges: [QuestBadgeWithSteps]
    public let origin: LatLng?
    public let destination: LatLng?

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        thumbnails: [MediaAsset] = [],
        badges: [QuestBadgeWithSteps] = [],
        origin: LatLng? = nil,
        destination: LatLng? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.thumbnails = thumbnails
        self.badges = badges
        self.origin = origin
        self.destination = destination
    }
}

// MARK: - QuestWithBadges
public struct QuestWithBadges: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let thumbnails: [MediaAsset]
    public let badges: [QuestBadgeEntry]

    public init(
        id: String,
        name: String,
        category: String,
        description: String,
        thumbnails: [MediaAsset] = [],
        badges: [QuestBadgeEntry] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.thumbnails = thumbnails
        self.badges = badges
    }
}

// MARK: - KelurahanQuestsGroup
public struct KelurahanQuestsGroup: Codable, Sendable, Equatable {
    public let kelurahan: Kelurahan
    public let quests: [Quest]

    public init(kelurahan: Kelurahan, quests: [Quest]) {
        self.kelurahan = kelurahan
        self.quests = quests
    }
}

// MARK: - Response Wrappers
struct QuestListResponse: Codable {
    let quests: [Quest]
}

struct QuestDetailResponse: Codable {
    let quest: QuestDetail
}

struct QuestBadgesResponse: Codable {
    let questBadges: [QuestBadgeEntry]
}

struct KelurahanQuestGroupsResponse: Codable {
    let groups: [KelurahanQuestsGroup]
}

public struct KelurahanDetailQuestsResponse: Codable, Sendable, Equatable {
    public let kelurahan: Kelurahan
    public let quests: [QuestWithBadges]
}
