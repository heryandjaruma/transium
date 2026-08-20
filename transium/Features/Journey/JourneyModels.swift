//
//  JourneyModels.swift
//  transium
//

import Foundation
import CoreLocation

extension String {
    /// "K5B-0" -> "K5B" — the suffix after a dash is an internal variant/direction marker,
    /// not part of the line name shown to users. Used wherever a `routeRef` is displayed.
    var truncatedAtDash: String {
        split(separator: "-").first.map(String.init) ?? self
    }
}

// MARK: - Journey Overview Response (/journey/overview)

public nonisolated struct JourneyResponse: Codable, Equatable, Sendable {
    public let alternativesAvailable: Bool
    public let best: JourneyResult
    public let lessWalking: JourneyResult?
    public let lessTransit: JourneyResult?

    public init(
        alternativesAvailable: Bool,
        best: JourneyResult,
        lessWalking: JourneyResult? = nil,
        lessTransit: JourneyResult? = nil
    ) {
        self.alternativesAvailable = alternativesAvailable
        self.best = best
        self.lessWalking = lessWalking
        self.lessTransit = lessTransit
    }
}

public nonisolated struct JourneyResult: Codable, Equatable, Sendable {
    public let origin: LatLng
    public let destination: LatLng
    public let summary: JourneyOverviewSummary
    public let segments: [JourneySegment]
    public let steps: [JourneyStep]

    public init(
        origin: LatLng,
        destination: LatLng,
        summary: JourneyOverviewSummary,
        segments: [JourneySegment],
        steps: [JourneyStep]
    ) {
        self.origin = origin
        self.destination = destination
        self.summary = summary
        self.segments = segments
        self.steps = steps
    }
}

public nonisolated struct JourneyOverviewSummary: Codable, Equatable, Sendable {
    public let distanceMeters: Double
    public let walkingDistanceMeters: Double
    public let walkingDurationSeconds: Double
    public let transitDistanceMeters: Double
    public let busLegCount: Int
    public let transferCount: Int

    public init(
        distanceMeters: Double,
        walkingDistanceMeters: Double,
        walkingDurationSeconds: Double,
        transitDistanceMeters: Double,
        busLegCount: Int,
        transferCount: Int
    ) {
        self.distanceMeters = distanceMeters
        self.walkingDistanceMeters = walkingDistanceMeters
        self.walkingDurationSeconds = walkingDurationSeconds
        self.transitDistanceMeters = transitDistanceMeters
        self.busLegCount = busLegCount
        self.transferCount = transferCount
    }
}

public nonisolated struct JourneyStep: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(type)-\(durationMinutes)-\(routeRef ?? "")-\(routeName ?? "")"
    }

    public let type: String // "walk" or "ride"
    public let durationMinutes: Double
    public let routeRef: String?
    public let routeName: String?

    public init(
        type: String,
        durationMinutes: Double,
        routeRef: String? = nil,
        routeName: String? = nil
    ) {
        self.type = type
        self.durationMinutes = durationMinutes
        self.routeRef = routeRef
        self.routeName = routeName
    }
}

public nonisolated struct JourneyLocationRef: Codable, Equatable, Sendable {
    public let lat: Double
    public let lng: Double
    public let name: String
    public let stopId: String?

    public init(
        lat: Double,
        lng: Double,
        name: String,
        stopId: String? = nil
    ) {
        self.lat = lat
        self.lng = lng
        self.name = name
        self.stopId = stopId
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

public nonisolated struct JourneyWalkStep: Codable, Equatable, Sendable {
    public let instructions: String
    public let distanceMeters: Double
    public let durationSeconds: Double
    public let geometry: [[Double]]

    public init(
        instructions: String,
        distanceMeters: Double,
        durationSeconds: Double,
        geometry: [[Double]] = []
    ) {
        self.instructions = instructions
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.geometry = geometry
    }
}

public nonisolated struct JourneySegment: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(type)-\(from.name)-\(to.name)-\(routeId ?? "")-\(distanceMeters ?? 0)"
    }

    public let type: String // "walk", "transfer", "bus"
    public let from: JourneyLocationRef
    public let to: JourneyLocationRef
    public let distanceMeters: Double?
    public let durationSeconds: Double?
    public let geometry: [[Double]]
    public let steps: [JourneyWalkStep]?

    // Bus-specific fields
    public let routeId: String?
    public let routeRef: String?
    public let routeName: String?
    public let routeColor: String?
    public let stops: [JourneyLocationRef]?

    public init(
        type: String,
        from: JourneyLocationRef,
        to: JourneyLocationRef,
        distanceMeters: Double? = nil,
        durationSeconds: Double? = nil,
        geometry: [[Double]] = [],
        steps: [JourneyWalkStep]? = nil,
        routeId: String? = nil,
        routeRef: String? = nil,
        routeName: String? = nil,
        routeColor: String? = nil,
        stops: [JourneyLocationRef]? = nil
    ) {
        self.type = type
        self.from = from
        self.to = to
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.geometry = geometry
        self.steps = steps
        self.routeId = routeId
        self.routeRef = routeRef
        self.routeName = routeName
        self.routeColor = routeColor
        self.stops = stops
    }

    public func withGeometry(_ newGeometry: [[Double]]) -> JourneySegment {
        JourneySegment(
            type: type,
            from: from,
            to: to,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            geometry: newGeometry,
            steps: steps,
            routeId: routeId,
            routeRef: routeRef,
            routeName: routeName,
            routeColor: routeColor,
            stops: stops
        )
    }

    private static let defaultWalkingSpeedMetersPerSecond: Double = 1.35

    /// Distance/duration to this segment's destination, recomputed live from the device's
    /// current position when available — so a "Walk to X" card can count down as the user
    /// actually gets closer, rather than showing the route's precomputed estimate for its
    /// whole length regardless of progress. Falls back to the segment's own precomputed
    /// values when no live position is available. Only meaningful for non-"bus" segments
    /// (walk/transfer) — there's no live vehicle position to track a bus leg against.
    public func liveRemaining(from currentLocation: CLLocationCoordinate2D?) -> (distanceMeters: Double?, durationSeconds: Double?) {
        guard let currentLocation else {
            return (distanceMeters, durationSeconds)
        }

        let liveDistance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            .distance(from: CLLocation(latitude: to.lat, longitude: to.lng))

        let pace: Double = {
            if let distanceMeters, let durationSeconds, distanceMeters > 0, durationSeconds > 0 {
                return distanceMeters / durationSeconds
            }
            return Self.defaultWalkingSpeedMetersPerSecond
        }()

        return (liveDistance, liveDistance / pace)
    }

    /// True when `location` lies within `toleranceMeters` of this segment's route geometry
    /// (nearest-vertex distance over the resolved road-following polyline — good enough to
    /// tell "on this road" from "nowhere near it" without true point-to-segment projection).
    /// Geometry points are `[lng, lat]` (see `RoadGeometryResolver`).
    public func isAligned(with location: CLLocationCoordinate2D?, toleranceMeters: Double = 80) -> Bool {
        guard let location, geometry.count > 1 else { return false }
        let point = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearestDistance = geometry.compactMap { coordinate -> Double? in
            guard coordinate.count >= 2 else { return nil }
            return CLLocation(latitude: coordinate[1], longitude: coordinate[0]).distance(from: point)
        }.min()
        return (nearestDistance ?? .infinity) <= toleranceMeters
    }
}

// MARK: - Journey Attempt Models (/private/journey/*)

public nonisolated struct JourneyAttempt: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let userQuestId: String
    // Documented as required by the OpenAPI spec, but POST /private/journey/go's response
    // currently omits them in practice — kept optional so decoding doesn't hard-fail on that.
    public let questId: String?
    public let questName: String?
    public let questCategory: String?
    public let currentStepSequence: Int
    public let status: String
    public let createdAt: Date
    public let startedAt: Date?
    public let endedAt: Date?

    public init(
        id: String,
        userQuestId: String,
        questId: String? = nil,
        questName: String? = nil,
        questCategory: String? = nil,
        currentStepSequence: Int,
        status: String,
        createdAt: Date,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.userQuestId = userQuestId
        self.questId = questId
        self.questName = questName
        self.questCategory = questCategory
        self.currentStepSequence = currentStepSequence
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public nonisolated enum JourneyAttemptStepStatus: String, Codable, Sendable {
    case waiting
    case done
}

public nonisolated struct JourneyAttemptStep: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let journeyAttemptId: String
    public let sequence: Int
    public let name: String
    public let description: String
    public let type: String
    public let lat: Double?
    public let lng: Double?
    public let radiusMeters: Double?
    public let status: JourneyAttemptStepStatus

    public init(
        id: String,
        journeyAttemptId: String,
        sequence: Int,
        name: String,
        description: String,
        type: String,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusMeters: Double? = nil,
        status: JourneyAttemptStepStatus = .waiting
    ) {
        self.id = id
        self.journeyAttemptId = journeyAttemptId
        self.sequence = sequence
        self.name = name
        self.description = description
        self.type = type
        self.lat = lat
        self.lng = lng
        self.radiusMeters = radiusMeters
        self.status = status
    }
}

/// A location the client should register a `CLCircularRegion` (or equivalent) for.
/// `radiusMeters` matches the owning step's tolerance, and is what POST .../advance checks against.
public nonisolated struct JourneyGeofence: Codable, Sendable, Equatable {
    public let stepId: String
    public let sequence: Int
    public let lat: Double
    public let lng: Double
    public let radiusMeters: Double

    public init(stepId: String, sequence: Int, lat: Double, lng: Double, radiusMeters: Double) {
        self.stepId = stepId
        self.sequence = sequence
        self.lat = lat
        self.lng = lng
        self.radiusMeters = radiusMeters
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

public nonisolated struct JourneySummary: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let journeyAttemptId: String
    public let stepsTaken: Int
    public let distanceMeters: Double
    public let calorie: Double
    public let startPoint: String
    public let finishPoint: String

    public init(
        id: String,
        journeyAttemptId: String,
        stepsTaken: Int,
        distanceMeters: Double,
        calorie: Double,
        startPoint: String,
        finishPoint: String
    ) {
        self.id = id
        self.journeyAttemptId = journeyAttemptId
        self.stepsTaken = stepsTaken
        self.distanceMeters = distanceMeters
        self.calorie = calorie
        self.startPoint = startPoint
        self.finishPoint = finishPoint
    }
}

// MARK: - Journey Request & Response Wrappers

public nonisolated struct StartJourneyRequest: Codable, Sendable {
    public let questId: String

    public init(questId: String) {
        self.questId = questId
    }
}

nonisolated struct StartJourneyResponse: Codable {
    let journeyAttempt: JourneyAttempt
    let steps: [JourneyAttemptStep]
    let geofences: [JourneyGeofence]
}

/// Result of POST /private/journey/go: the created attempt, its ordered quest steps,
/// and the geofences the client should register a CLCircularRegion for.
public nonisolated struct JourneyGoResult: Sendable, Equatable {
    public let journeyAttempt: JourneyAttempt
    public let steps: [JourneyAttemptStep]
    public let geofences: [JourneyGeofence]

    public init(journeyAttempt: JourneyAttempt, steps: [JourneyAttemptStep], geofences: [JourneyGeofence]) {
        self.journeyAttempt = journeyAttempt
        self.steps = steps
        self.geofences = geofences
    }
}

public nonisolated struct AdvanceJourneyRequest: Codable, Sendable {
    public let stepId: String
    public let lat: Double
    public let lng: Double

    public init(stepId: String, lat: Double, lng: Double) {
        self.stepId = stepId
        self.lat = lat
        self.lng = lng
    }
}

nonisolated struct AdvanceJourneyResponse: Codable {
    let journeyAttempt: JourneyAttempt
    let steps: [JourneyAttemptStep]
}

/// Result of POST /private/journey/{id}/advance: the (possibly unchanged) attempt and its steps.
public nonisolated struct JourneyAdvanceResult: Sendable, Equatable {
    public let journeyAttempt: JourneyAttempt
    public let steps: [JourneyAttemptStep]

    public init(journeyAttempt: JourneyAttempt, steps: [JourneyAttemptStep]) {
        self.journeyAttempt = journeyAttempt
        self.steps = steps
    }
}

nonisolated struct CancelJourneyResponse: Codable {
    let journeyAttempt: JourneyAttempt
}

/// The 409 body POST /private/journey/go returns when the caller already has a
/// `status: "started"` attempt — for this quest or another one.
nonisolated struct JourneyConflictInfo: Codable {
    let error: String
    let activeJourneyAttemptId: String?
}

/// Thrown by `JourneyService.startJourney` in place of the generic `TransiumAPIError.conflict`
/// when the 409 body could be parsed, so callers can offer to resume or cancel the
/// existing attempt instead of just showing an error.
public nonisolated struct JourneyStartConflictError: Error, Sendable, Equatable {
    public let message: String
    public let activeJourneyAttemptId: String?

    public init(message: String, activeJourneyAttemptId: String?) {
        self.message = message
        self.activeJourneyAttemptId = activeJourneyAttemptId
    }
}

nonisolated struct JourneyAttemptListResponse: Codable {
    let journeyAttempts: [JourneyAttempt]
}

/// Response of GET /private/journey/current: the caller's single in-progress attempt
/// (`status: "started"`), if any — `journeyAttempt` is `nil` (with empty `steps`) when
/// nothing is active. A user can only ever have one such attempt at a time.
public nonisolated struct JourneyCurrentResponse: Codable, Sendable, Equatable {
    public let journeyAttempt: JourneyAttempt?
    public let steps: [JourneyAttemptStep]

    public init(journeyAttempt: JourneyAttempt?, steps: [JourneyAttemptStep]) {
        self.journeyAttempt = journeyAttempt
        self.steps = steps
    }
}

public nonisolated struct JourneyAttemptDetailResponse: Codable, Sendable, Equatable {
    public let journeyAttempt: JourneyAttempt
    public let journeyAttemptSteps: [JourneyAttemptStep]
    public let journeySummary: JourneySummary?

    public init(
        journeyAttempt: JourneyAttempt,
        journeyAttemptSteps: [JourneyAttemptStep],
        journeySummary: JourneySummary? = nil
    ) {
        self.journeyAttempt = journeyAttempt
        self.journeyAttemptSteps = journeyAttemptSteps
        self.journeySummary = journeySummary
    }
}

public nonisolated struct JourneyMediaResponse: Codable, Sendable {
    public let media: MediaAsset

    public init(media: MediaAsset) {
        self.media = media
    }
}
