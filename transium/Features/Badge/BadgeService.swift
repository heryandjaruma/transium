//
//  BadgeService.swift
//  transium
//

import Foundation

public protocol BadgeServiceProtocol: Sendable {
    /// Returns the badges the caller has earned, most recently earned first.
    func listEarnedBadges() async throws -> [EarnedBadge]
}

public final class BadgeService: BadgeServiceProtocol, Sendable {
    public static let shared = BadgeService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func listEarnedBadges() async throws -> [EarnedBadge] {
        let response: EarnedBadgesResponse = try await apiClient.request(
            path: "/private/badge",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.badges
    }
}

private struct EarnedBadgesResponse: Codable {
    let badges: [EarnedBadge]
}
