//
//  GalleryService.swift
//  transium
//

import Foundation

public protocol GalleryServiceProtocol: Sendable {
    /// Returns a page of photos the caller has uploaded to any journey attempt, most recent
    /// first. `page` is 1-based; `limit` is 1-100 (default 20).
    func listGallery(page: Int, limit: Int) async throws -> GalleryPage

    /// Downloads a photo's raw bytes from the caller's gallery, for saving as a file.
    func downloadPhoto(id: String) async throws -> Data
}

public final class GalleryService: GalleryServiceProtocol, Sendable {
    public static let shared = GalleryService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func listGallery(page: Int = 1, limit: Int = 20) async throws -> GalleryPage {
        try await apiClient.request(
            path: "/private/gallery",
            method: .get,
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ],
            body: nil,
            requiresAuth: true
        )
    }

    public func downloadPhoto(id: String) async throws -> Data {
        try await apiClient.requestData(
            path: "/private/gallery/\(id)",
            method: .get,
            queryItems: nil,
            requiresAuth: true
        )
    }
}
