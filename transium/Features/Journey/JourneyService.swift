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
    
    /// Plan a real door-to-door journey to a quest from the user's origin.
    func getRealJourney(questId: String, origin: LatLng) async throws -> JourneyResponse
    
    /// Convenience helper for CLLocationCoordinate2D.
    func fetchRealJourney(questId: String, origin: CLLocationCoordinate2D) async throws -> JourneyResponse
    
    /// Start a journey attempt for a quest. Returns the attempt, its ordered quest steps,
    /// and the geofences the client should register for step-arrival detection.
    func startJourney(questId: String) async throws -> JourneyGoResult

    /// Report a geofence trigger (or a manual arrival check) for a step on an in-progress attempt.
    func advanceJourney(attemptId: String, stepId: String, lat: Double, lng: Double) async throws -> JourneyAdvanceResult

    /// Cancel an in-progress journey attempt, freeing the caller to start a new one.
    func cancelJourney(attemptId: String) async throws -> JourneyAttempt

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

    public func getRealJourney(questId: String, origin: LatLng) async throws -> JourneyResponse {
        let originStr = "\(origin.lat),\(origin.lng)"
        let queryItems = [
            URLQueryItem(name: "questId", value: questId),
            URLQueryItem(name: "origin", value: originStr)
        ]

        return try await apiClient.request(
            path: "/journey/real",
            method: .get,
            queryItems: queryItems,
            body: nil,
            requiresAuth: false
        )
    }

    public func fetchRealJourney(questId: String, origin: CLLocationCoordinate2D) async throws -> JourneyResponse {
        try await getRealJourney(
            questId: questId,
            origin: LatLng(coordinate: origin)
        )
    }

    public func startJourney(questId: String) async throws -> JourneyGoResult {
        let body = StartJourneyRequest(questId: questId)
        do {
            let response: StartJourneyResponse = try await apiClient.request(
                path: "/private/journey/go",
                method: .post,
                queryItems: nil,
                body: body,
                requiresAuth: true
            )
            return JourneyGoResult(journeyAttempt: response.journeyAttempt, steps: response.steps, geofences: response.geofences)
        } catch TransiumAPIError.conflict(let message, let rawData) {
            let info = rawData.flatMap { try? JSONDecoder().decode(JourneyConflictInfo.self, from: $0) }
            throw JourneyStartConflictError(message: info?.error ?? message, activeJourneyAttemptId: info?.activeJourneyAttemptId)
        }
    }

    public func advanceJourney(attemptId: String, stepId: String, lat: Double, lng: Double) async throws -> JourneyAdvanceResult {
        let body = AdvanceJourneyRequest(stepId: stepId, lat: lat, lng: lng)
        let response: AdvanceJourneyResponse = try await apiClient.request(
            path: "/private/journey/\(attemptId)/advance",
            method: .post,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
        return JourneyAdvanceResult(journeyAttempt: response.journeyAttempt, steps: response.steps)
    }

    public func cancelJourney(attemptId: String) async throws -> JourneyAttempt {
        let response: CancelJourneyResponse = try await apiClient.request(
            path: "/private/journey/\(attemptId)/cancel",
            method: .post,
            queryItems: nil,
            body: nil,
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
