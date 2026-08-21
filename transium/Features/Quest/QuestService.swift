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
    func listKelurahanQuests(origin: String?) async throws -> [KelurahanQuestsGroup]
    
    /// Returns the quests reachable in a specific kelurahan with badges.
    func getKelurahanQuests(id: String, origin: String?) async throws -> KelurahanDetailQuestsResponse
}

extension QuestServiceProtocol {
    public func listKelurahanQuests() async throws -> [KelurahanQuestsGroup] {
        try await listKelurahanQuests(origin: nil)
    }

    public func getKelurahanQuests(id: String) async throws -> KelurahanDetailQuestsResponse {
        try await getKelurahanQuests(id: id, origin: nil)
    }
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

    public func listKelurahanQuests(origin: String? = nil) async throws -> [KelurahanQuestsGroup] {
        var queryItems: [URLQueryItem]? = nil
        if let origin, !origin.isEmpty {
            queryItems = [URLQueryItem(name: "origin", value: origin)]
        }
        let response: KelurahanQuestGroupsResponse = try await apiClient.request(
            path: "/private/kelurahan/quest",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: true
        )
        return response.groups
    }

    public func getKelurahanQuests(id: String, origin: String? = nil) async throws -> KelurahanDetailQuestsResponse {
        var queryItems: [URLQueryItem]? = nil
        if let origin, !origin.isEmpty {
            queryItems = [URLQueryItem(name: "origin", value: origin)]
        }
        return try await apiClient.request(
            path: "/private/kelurahan/\(id)/quest",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: true
        )
    }
}
