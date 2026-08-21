//
//  LocationService.swift
//  transium
//

import Foundation

public protocol LocationServiceProtocol: Sendable {
    /// Search-as-you-type place/address suggestions for Bali.
    func search(query: String) async throws -> [AutocompleteSuggestion]
    
    /// Resolve a search suggestion's resolveToken into coordinates.
    func resolve(token: String) async throws -> [PlaceSuggestion]
    
    /// Resolve a full address or place name to coordinates (tries Apple Maps first, falls back to OSM).
    func geocode(query: String) async throws -> GeocodeResult

    /// Resolve coordinates to a readable address (tries Apple Maps first, falls back to OSM) —
    /// the inverse of `geocode(query:)`, used to show a live address while dragging a pin.
    func reverseGeocode(lat: Double, lng: Double) async throws -> GeocodeResult
}

public final class LocationService: LocationServiceProtocol, Sendable {
    public static let shared = LocationService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func search(query: String) async throws -> [AutocompleteSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryItems = [URLQueryItem(name: "q", value: trimmed)]
        let response: AutocompleteSearchResponse = try await apiClient.request(
            path: "/maps/search",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
        return response.results
    }

    public func resolve(token: String) async throws -> [PlaceSuggestion] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryItems = [URLQueryItem(name: "token", value: trimmed)]
        let response: PlaceResolveResponse = try await apiClient.request(
            path: "/maps/search/resolve",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
        return response.results
    }

    public func geocode(query: String) async throws -> GeocodeResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return GeocodeResult(results: [], source: .apple)
        }

        let queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return try await apiClient.request(
            path: "/maps/geocode",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
    }

    public func reverseGeocode(lat: Double, lng: Double) async throws -> GeocodeResult {
        let queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng))
        ]
        return try await apiClient.request(
            path: "/maps/reverse-geocode",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
    }
}
