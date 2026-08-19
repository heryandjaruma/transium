//
//  JourneyService.swift
//  transium
//

import CoreLocation
import Foundation

public protocol JourneyServiceProtocol: Sendable {
    /// Plan a door-to-door journey between two coordinates.
    func getOverview(origin: LatLng, destination: LatLng) async throws -> JourneyResponse
    
    /// Convenience helper for CLLocationCoordinate2D.
    func fetchJourneyOverview(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) async throws -> JourneyResponse
    
    /// Start a journey attempt for a quest.
    func startJourney(questId: String) async throws -> JourneyAttempt
    
    /// List the caller's journey attempts.
    func listJourneyAttempts() async throws -> [JourneyAttempt]
    
    /// Get a single journey attempt with its steps and summary.
    func getJourneyAttempt(id: String) async throws -> JourneyAttemptDetailResponse
    
    /// Upload a photo for a journey step.
    func uploadStepMedia(stepId: String, imageData: Data, filename: String, mimeType: String) async throws -> MediaAsset
}

public final class JourneyService: JourneyServiceProtocol, Sendable {
    public static let shared = JourneyService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func getOverview(origin: LatLng, destination: LatLng) async throws -> JourneyResponse {
        let originStr = "\(origin.lat),\(origin.lng)"
        let destStr = "\(destination.lat),\(destination.lng)"

        let queryItems = [
            URLQueryItem(name: "origin", value: originStr),
            URLQueryItem(name: "destination", value: destStr)
        ]

        return try await apiClient.request(
            path: "/journey/overview",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
    }

    public func fetchJourneyOverview(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) async throws -> JourneyResponse {
        try await getOverview(
            origin: LatLng(coordinate: origin),
            destination: LatLng(coordinate: destination)
        )
    }

    public func startJourney(questId: String) async throws -> JourneyAttempt {
        let body = StartJourneyRequest(questId: questId)
        let response: StartJourneyResponse = try await apiClient.request(
            path: "/private/journey/go",
            method: .post,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
        return response.journeyAttempt
    }

    public func listJourneyAttempts() async throws -> [JourneyAttempt] {
        let response: JourneyAttemptListResponse = try await apiClient.request(
            path: "/private/journey",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.journeyAttempts
    }

    public func getJourneyAttempt(id: String) async throws -> JourneyAttemptDetailResponse {
        return try await apiClient.request(
            path: "/private/journey/\(id)",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
    }

    public func uploadStepMedia(
        stepId: String,
        imageData: Data,
        filename: String = "step.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> MediaAsset {
        var multipart = MultipartFormData()
        multipart.appendField(name: "journeyAttemptStepId", value: stepId)
        multipart.appendFile(
            fieldName: "file",
            fileName: filename,
            mimeType: mimeType,
            fileData: imageData
        )

        let response: JourneyMediaResponse = try await apiClient.upload(
            path: "/private/journey/media",
            multipart: multipart,
            requiresAuth: true
        )
        return response.media
    }
}
