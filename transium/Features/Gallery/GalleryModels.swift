//
//  GalleryModels.swift
//  transium
//

import Foundation

// MARK: - GalleryItem
/// A photo the caller uploaded to a journey (either a specific step, or the attempt itself),
/// with enough context to group/label it in a gallery view.
public nonisolated struct GalleryItem: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let type: String
    public let url: String
    public let alt: String?
    public let copyright: String?
    /// Null when this photo was uploaded against the journey attempt directly rather than one
    /// of its steps.
    public let journeyStepId: String?
    public let journeyStepName: String?
    public let journeyStepSequence: Int?
    public let journeyAttemptId: String
    public let questId: String
    public let questName: String

    public init(
        id: String,
        createdAt: String,
        type: String,
        url: String,
        alt: String? = nil,
        copyright: String? = nil,
        journeyStepId: String? = nil,
        journeyStepName: String? = nil,
        journeyStepSequence: Int? = nil,
        journeyAttemptId: String,
        questId: String,
        questName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.url = url
        self.alt = alt
        self.copyright = copyright
        self.journeyStepId = journeyStepId
        self.journeyStepName = journeyStepName
        self.journeyStepSequence = journeyStepSequence
        self.journeyAttemptId = journeyAttemptId
        self.questId = questId
        self.questName = questName
    }
}

// MARK: - GalleryPagination
public nonisolated struct GalleryPagination: Codable, Sendable, Equatable {
    public let page: Int
    public let limit: Int
    public let total: Int
    public let totalPages: Int
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool

    public init(page: Int, limit: Int, total: Int, totalPages: Int, hasNextPage: Bool, hasPreviousPage: Bool) {
        self.page = page
        self.limit = limit
        self.total = total
        self.totalPages = totalPages
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
    }
}

// MARK: - Response Wrapper
public nonisolated struct GalleryPage: Codable, Sendable, Equatable {
    public let media: [GalleryItem]
    public let pagination: GalleryPagination

    public init(media: [GalleryItem], pagination: GalleryPagination) {
        self.media = media
        self.pagination = pagination
    }
}
