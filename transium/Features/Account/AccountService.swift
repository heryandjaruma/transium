//
//  AccountService.swift
//  transium
//

import Foundation

public protocol AccountServiceProtocol: Sendable {
    /// Permanently deletes the caller's account and all associated data.
    /// Irreversible; the server performs no confirmation step of its own.
    func deleteAccount() async throws
}

public final class AccountService: AccountServiceProtocol, Sendable {
    public static let shared = AccountService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func deleteAccount() async throws {
        try await apiClient.requestVoid(
            path: "/private/account",
            method: .delete,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
    }
}
