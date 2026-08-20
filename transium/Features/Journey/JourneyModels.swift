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

    /// The journey's true final destination name. When the journey ends in a mission (the
    /// common case for GET /journey/real quests with a badge action at the destination — its
    /// segment has no `to`, only `instructions`), that instruction is the destination-facing
    /// name; otherwise it's the last travel leg's arrival point.
    public var destinationName: String {
        guard let lastSegment = segments.last else { return "Destination" }
        if lastSegment.isMission {
            return lastSegment.instructions ?? "Destination"
        }
        return lastSegment.to?.name ?? "Destination"
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
        "\(type)-\(durationMinutes ?? 0)-\(routeRef ?? "")-\(routeName ?? "")-\(instructions ?? "")"
    }

    public let type: String // "walk", "ride", or "mission" (mission: /journey/real only)
    public let durationMinutes: Double? // absent on "mission" entries
    public let routeRef: String?
    public let routeName: String?

    /// A quest step the user must actually do — only present when `type == "mission"`, and
    /// only ever emitted by GET /journey/real (never /journey/overview). Appears right after
    /// the travel leg (if any) that reaches it, mirroring the `mission` entries in
    /// `JourneyResult.segments`.
    public let instructions: String?
    /// Present only when the mission's BadgeAction carries coordinates.
    public let lat: Double?
    public let lng: Double?
    /// Exact join key to the corresponding `JourneyAttemptStep.id` — only resolved when the
    /// request that fetched this journey passed an authenticated `journeyAttemptId` the caller
    /// actually owns; nil otherwise (e.g. previewing a quest before starting it).
    public let stepId: String?

    public init(
        type: String,
        durationMinutes: Double? = nil,
        routeRef: String? = nil,
        routeName: String? = nil,
        instructions: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        stepId: String? = nil
    ) {
        self.type = type
        self.durationMinutes = durationMinutes
        self.routeRef = routeRef
        self.routeName = routeName
        self.instructions = instructions
        self.lat = lat
        self.lng = lng
        self.stepId = stepId
    }

    public var isMission: Bool { type == "mission" }
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
        if isMission {
            return "mission-\(instructions ?? "")-\(lat ?? 0)-\(lng ?? 0)"
        }
        return "\(type)-\(from?.name ?? "")-\(to?.name ?? "")-\(routeId ?? "")-\(distanceMeters ?? 0)"
    }

    public let type: String // "walk", "transfer", "bus", or "mission" (mission: /journey/real only)

    // Absent on "mission" segments — a mission is a quest step the user must do, not a travel
    // leg, so it carries none of the travel fields below (see `instructions`/`lat`/`lng` instead).
    public let from: JourneyLocationRef?
    public let to: JourneyLocationRef?
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

    // Mission-specific fields (GET /journey/real only). Appears right after the travel leg (if
    // any) that reaches it, in the same badge-attachment/step-sequence order GET /quest/{id} and
    // POST /private/journey/go use.
    /// The BadgeAction's own instruction, or its ActionDefinition's name if unset.
    public let instructions: String?
    /// Present only when the BadgeAction carries coordinates. When absent, no travel leg is
    /// routed to this mission.
    public let lat: Double?
    public let lng: Double?
    /// Exact join key to the corresponding `JourneyAttemptStep.id` — only resolved when the
    /// request that fetched this journey passed an authenticated `journeyAttemptId` the caller
    /// actually owns; nil otherwise (e.g. previewing a quest before starting it).
    public let stepId: String?

    public init(
        type: String,
        from: JourneyLocationRef? = nil,
        to: JourneyLocationRef? = nil,
        distanceMeters: Double? = nil,
        durationSeconds: Double? = nil,
        geometry: [[Double]] = [],
        steps: [JourneyWalkStep]? = nil,
        routeId: String? = nil,
        routeRef: String? = nil,
        routeName: String? = nil,
        routeColor: String? = nil,
        stops: [JourneyLocationRef]? = nil,
        instructions: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        stepId: String? = nil
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
        self.instructions = instructions
        self.lat = lat
        self.lng = lng
        self.stepId = stepId
    }

    private enum CodingKeys: String, CodingKey {
        case type, from, to, distanceMeters, durationSeconds, geometry, steps
        case routeId, routeRef, routeName, routeColor, stops
        case instructions, lat, lng, stepId
    }

    // Custom decode so a "mission" entry — which the API sends with only `type`, `instructions`,
    // and optionally `lat`/`lng`/`stepId` — doesn't fail decoding the shared `segments` array
    // just because it omits every travel field (`from`/`to`/`geometry`/...) a walk/bus/transfer
    // segment has.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        from = try container.decodeIfPresent(JourneyLocationRef.self, forKey: .from)
        to = try container.decodeIfPresent(JourneyLocationRef.self, forKey: .to)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        geometry = try container.decodeIfPresent([[Double]].self, forKey: .geometry) ?? []
        steps = try container.decodeIfPresent([JourneyWalkStep].self, forKey: .steps)
        routeId = try container.decodeIfPresent(String.self, forKey: .routeId)
        routeRef = try container.decodeIfPresent(String.self, forKey: .routeRef)
        routeName = try container.decodeIfPresent(String.self, forKey: .routeName)
        routeColor = try container.decodeIfPresent(String.self, forKey: .routeColor)
        stops = try container.decodeIfPresent([JourneyLocationRef].self, forKey: .stops)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        stepId = try container.decodeIfPresent(String.self, forKey: .stepId)
    }

    public var isMission: Bool { type == "mission" }

    public var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
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
            stops: stops,
            instructions: instructions,
            lat: lat,
            lng: lng,
            stepId: stepId
        )
    }

    private static let defaultWalkingSpeedMetersPerSecond: Double = 1.35

    /// Distance/duration to this segment's destination, recomputed live from the device's
    /// current position when available — so a "Walk to X" card can count down as the user
    /// actually gets closer, rather than showing the route's precomputed estimate for its
    /// whole length regardless of progress. Falls back to the segment's own precomputed
    /// values when no live position is available. Only meaningful for non-"bus" segments
    /// (walk/transfer) — there's no live vehicle position to track a bus leg against. Missions
    /// have no `to` to walk toward, so they fall back the same way "no live position" does.
    public func liveRemaining(from currentLocation: CLLocationCoordinate2D?) -> (distanceMeters: Double?, durationSeconds: Double?) {
        guard let currentLocation, let to else {
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
    public func isAligned(with location: CLLocationCoordinate2D?, toleranceMeters: Double = 100) -> Bool {
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
    /// The step's ActionDefinition.type — a free-text kind of action (e.g. "capture",
    /// "checkin"), unrelated to `type`'s required/optional-ness. POST /private/journey/go no
    /// longer emits synthetic "takePicture" checkpoints, so every step maps to a real
    /// ActionDefinition — kept optional defensively rather than because it's expected to be nil.
    public let actionType: String?
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
        actionType: String? = nil,
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
        self.actionType = actionType
        self.lat = lat
        self.lng = lng
        self.radiusMeters = radiusMeters
        self.status = status
    }

    /// True for a step whose action requires a photo capture — the ActionDefinition.type
    /// contains "capture". POST /private/journey/go no longer emits synthetic `"takePicture"`
    /// checkpoints (removed server-side — every step now maps to a real BadgeAction), so this
    /// is driven purely by `actionType`.
    public var isPhotoCheckpoint: Bool {
        actionType?.localizedCaseInsensitiveContains("capture") ?? false
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
    /// Approximate IDR cost of the private-motorcycle fuel this distance would have used,
    /// derived from `distanceMeters` (not a real fare quote) and rounded to the nearest Rp 5,000.
    public let fuelCostSavedIdr: Int?
    /// Approximate IDR fare an ojek-online (ride-hailing motorcycle) trip of this distance
    /// would have cost, derived from `distanceMeters` and rounded to the nearest Rp 5,000.
    public let rideHailingMotorcycleSavedIdr: Int?
    /// Approximate IDR fare a ride-hailing car trip of this distance would have cost, derived
    /// from `distanceMeters` and rounded to the nearest Rp 5,000.
    public let rideHailingCarSavedIdr: Int?

    public init(
        id: String,
        journeyAttemptId: String,
        stepsTaken: Int,
        distanceMeters: Double,
        calorie: Double,
        startPoint: String,
        finishPoint: String,
        fuelCostSavedIdr: Int? = nil,
        rideHailingMotorcycleSavedIdr: Int? = nil,
        rideHailingCarSavedIdr: Int? = nil
    ) {
        self.id = id
        self.journeyAttemptId = journeyAttemptId
        self.stepsTaken = stepsTaken
        self.distanceMeters = distanceMeters
        self.calorie = calorie
        self.startPoint = startPoint
        self.finishPoint = finishPoint
        self.fuelCostSavedIdr = fuelCostSavedIdr
        self.rideHailingMotorcycleSavedIdr = rideHailingMotorcycleSavedIdr
        self.rideHailingCarSavedIdr = rideHailingCarSavedIdr
    }
}

/// One GPS sample from the device's recorded breadcrumb for a journey attempt, in walked order.
public nonisolated struct JourneyPathPoint: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let journeyAttemptId: String
    public let sequence: Int
    public let lat: Double
    public let lng: Double
    public let recordedAt: Date?

    public init(
        id: String,
        journeyAttemptId: String,
        sequence: Int,
        lat: Double,
        lng: Double,
        recordedAt: Date? = nil
    ) {
        self.id = id
        self.journeyAttemptId = journeyAttemptId
        self.sequence = sequence
        self.lat = lat
        self.lng = lng
        self.recordedAt = recordedAt
    }
}

/// One breadcrumb sample the client sends to POST /private/journey/{id}/complete — the request
/// counterpart to `JourneyPathPoint` (no `id`/`journeyAttemptId`/`sequence`; the server assigns
/// those on write).
public nonisolated struct JourneyPathPointInput: Encodable, Sendable, Equatable {
    public let lat: Double
    public let lng: Double
    public let recordedAt: Date?

    public init(lat: Double, lng: Double, recordedAt: Date? = nil) {
        self.lat = lat
        self.lng = lng
        self.recordedAt = recordedAt
    }
}

/// A badge the caller has earned (a UserBadge row joined with its Badge). Awarded automatically
/// by POST /private/journey/{id}/complete for every Badge attached to a quest whose journey the
/// caller just finished, skipping any they already have.
public nonisolated struct EarnedBadge: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let badgeId: String
    public let badgeName: String
    public let badgeCategory: String
    public let badgeType: String
    public let badgeImageUrl: String?
    public let earnedAt: Date
    public let questId: String?
    public let questName: String?

    public init(
        id: String,
        badgeId: String,
        badgeName: String,
        badgeCategory: String,
        badgeType: String,
        badgeImageUrl: String? = nil,
        earnedAt: Date,
        questId: String? = nil,
        questName: String? = nil
    ) {
        self.id = id
        self.badgeId = badgeId
        self.badgeName = badgeName
        self.badgeCategory = badgeCategory
        self.badgeType = badgeType
        self.badgeImageUrl = badgeImageUrl
        self.earnedAt = earnedAt
        self.questId = questId
        self.questName = questName
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
public nonisolated struct JourneyGoResult: Codable, Sendable, Equatable {
    public let journeyAttempt: JourneyAttempt
    public let steps: [JourneyAttemptStep]
    public let geofences: [JourneyGeofence]

    public init(journeyAttempt: JourneyAttempt, steps: [JourneyAttemptStep], geofences: [JourneyGeofence]) {
        self.journeyAttempt = journeyAttempt
        self.steps = steps
        self.geofences = geofences
    }
}

/// A located step (has lat/lng) is proven by geofence: `lat`/`lng` are required and checked
/// against the step's own coordinates (~150m). An unlocated step has nothing to prove against,
/// so they're optional and ignored if sent — passing just `stepId` is itself the "I did this"
/// attestation, trusted client-side with no server-side verification.
public nonisolated struct AdvanceJourneyRequest: Codable, Sendable {
    public let stepId: String
    public let lat: Double?
    public let lng: Double?

    public init(stepId: String, lat: Double? = nil, lng: Double? = nil) {
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

/// Body for POST /private/journey/{id}/complete. Unlike /advance, this endpoint never marks
/// steps done itself — it only finalizes an attempt whose steps are *already* all `"done"`,
/// so the client assembles data the server can't derive on its own (device step count,
/// distance/calories, and the walked breadcrumb) and submits it here.
public nonisolated struct CompleteJourneyRequest: Encodable, Sendable {
    public let stepsTaken: Int
    public let distanceMeters: Double
    public let calorie: Double
    public let startPoint: String
    public let finishPoint: String
    public let path: [JourneyPathPointInput]

    public init(
        stepsTaken: Int,
        distanceMeters: Double,
        calorie: Double,
        startPoint: String,
        finishPoint: String,
        path: [JourneyPathPointInput]
    ) {
        self.stepsTaken = stepsTaken
        self.distanceMeters = distanceMeters
        self.calorie = calorie
        self.startPoint = startPoint
        self.finishPoint = finishPoint
        self.path = path
    }
}

nonisolated struct CompleteJourneyResponse: Codable {
    let journeyAttempt: JourneyAttempt
    let steps: [JourneyAttemptStep]
    // Documented as required, but the idempotent-no-op path (attempt already "completed" —
    // notably including when /advance's own auto-completion beat this call to it) returns
    // `null` in practice, since no JourneySummary row was ever created. Kept optional so
    // decoding doesn't hard-fail on that.
    let summary: JourneySummary?
    let path: [JourneyPathPoint]
    let xpAwarded: Int
    let badgesAwarded: [EarnedBadge]
    let profile: Profile
}

/// Result of POST /private/journey/{id}/complete: the now-`"completed"` attempt, the awarded
/// XP/badges, and the caller's updated profile. Idempotent — calling this again on an
/// already-completed attempt returns it unchanged with `xpAwarded: 0`, `badgesAwarded: []`,
/// and `summary: nil` (no JourneySummary row exists for that path).
public nonisolated struct JourneyCompleteResult: Identifiable, Sendable, Equatable {
    public var id: String { journeyAttempt.id }

    public let journeyAttempt: JourneyAttempt
    public let steps: [JourneyAttemptStep]
    public let summary: JourneySummary?
    public let path: [JourneyPathPoint]
    public let xpAwarded: Int
    public let badgesAwarded: [EarnedBadge]
    public let profile: Profile

    public init(
        journeyAttempt: JourneyAttempt,
        steps: [JourneyAttemptStep],
        summary: JourneySummary?,
        path: [JourneyPathPoint],
        xpAwarded: Int,
        badgesAwarded: [EarnedBadge],
        profile: Profile
    ) {
        self.journeyAttempt = journeyAttempt
        self.steps = steps
        self.summary = summary
        self.path = path
        self.xpAwarded = xpAwarded
        self.badgesAwarded = badgesAwarded
        self.profile = profile
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
