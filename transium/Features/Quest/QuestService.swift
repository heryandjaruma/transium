//
//  QuestService.swift
//  transium
//

import Foundation

public protocol QuestServiceProtocol: Sendable {
    /// Returns every quest with its thumbnail media.
    func listQuests() async throws -> [Quest]
    
    /// Returns a quest with its thumbnails, attached badges, steps, and origin/destination coordinates.
    func getQuest(id: String) async throws -> QuestDetail
    
    /// Lists badges attached to a specific quest.
    func listQuestBadges(id: String) async throws -> [QuestBadgeEntry]
    
    /// Returns each kelurahan that has at least one reachable quest paired with those quests.
    func listKelurahanQuests() async throws -> [KelurahanQuestsGroup]
    
    /// Returns the quests reachable in a specific kelurahan with badges.
    func getKelurahanQuests(id: String) async throws -> KelurahanDetailQuestsResponse
}

public final class QuestService: QuestServiceProtocol, Sendable {
    public static let shared = QuestService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func listQuests() async throws -> [Quest] {
        let response: QuestListResponse = try await apiClient.request(
            path: "/quest",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: false
        )
        return response.quests
    }

    public func getQuest(id: String) async throws -> QuestDetail {
        let response: QuestDetailResponse = try await apiClient.request(
            path: "/quest/\(id)",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: false
        )
        return response.quest
    }

    public func listQuestBadges(id: String) async throws -> [QuestBadgeEntry] {
        let response: QuestBadgesResponse = try await apiClient.request(
            path: "/quest/\(id)/badges",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: false
        )
        return response.questBadges
    }

    public func listKelurahanQuests() async throws -> [KelurahanQuestsGroup] {
        let response: KelurahanQuestGroupsResponse = try await apiClient.request(
            path: "/kelurahan/quests",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: false
        )
        return response.groups
    }

    public func getKelurahanQuests(id: String) async throws -> KelurahanDetailQuestsResponse {
        return try await apiClient.request(
            path: "/kelurahan/\(id)/quests",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: false
        )
    }
}
