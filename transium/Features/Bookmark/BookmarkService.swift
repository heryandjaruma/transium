//
//  BookmarkService.swift
//  transium
//

import Foundation

public protocol BookmarkServiceProtocol: Sendable {
    /// List the caller's bookmarked quests.
    func listBookmarks() async throws -> [Bookmark]
    
    /// Bookmark a quest for the caller.
    func addBookmark(questId: String) async throws -> Bookmark
    
    /// Remove a bookmarked quest.
    func removeBookmark(questId: String) async throws
}

public final class BookmarkService: BookmarkServiceProtocol, Sendable {
    public static let shared = BookmarkService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func listBookmarks() async throws -> [Bookmark] {
        let response: BookmarkListResponse = try await apiClient.request(
            path: "/private/bookmark",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.bookmarks
    }

    public func addBookmark(questId: String) async throws -> Bookmark {
        let body = BookmarkRequest(questId: questId)
        let response: BookmarkCreateResponse = try await apiClient.request(
            path: "/private/bookmark",
            method: .post,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
        return response.bookmark
    }

    public func removeBookmark(questId: String) async throws {
        let body = BookmarkRequest(questId: questId)
        try await apiClient.requestVoid(
            path: "/private/bookmark",
            method: .delete,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
    }
}
