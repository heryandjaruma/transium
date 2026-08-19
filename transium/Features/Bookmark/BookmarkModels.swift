//
//  BookmarkModels.swift
//  transium
//

import Foundation

// MARK: - Bookmark
public struct Bookmark: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let questId: String
    public let questName: String
    public let questCategory: String
    public let createdAt: Date

    public init(
        id: String,
        questId: String,
        questName: String,
        questCategory: String,
        createdAt: Date
    ) {
        self.id = id
        self.questId = questId
        self.questName = questName
        self.questCategory = questCategory
        self.createdAt = createdAt
    }
}

// MARK: - Request Payloads
public struct BookmarkRequest: Codable, Sendable {
    public let questId: String

    public init(questId: String) {
        self.questId = questId
    }
}

// MARK: - Response Wrappers
struct BookmarkListResponse: Codable {
    let bookmarks: [Bookmark]
}

struct BookmarkCreateResponse: Codable {
    let bookmark: Bookmark
}
