//
//  JourneyModels.swift
//  transium
//

import Foundation
import CoreLocation

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
}

// MARK: - Journey Attempt Models (/private/journey/*)

public nonisolated struct JourneyAttempt: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let userQuestId: String
    public let questId: String
    public let questName: String
    public let questCategory: String
    public let currentStepSequence: Int
    public let status: String
    public let createdAt: Date
    public let startedAt: Date?
    public let endedAt: Date?

    public init(
        id: String,
        userQuestId: String,
        questId: String,
        questName: String,
        questCategory: String,
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
        self.status = status
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
}

nonisolated struct JourneyAttemptListResponse: Codable {
    let journeyAttempts: [JourneyAttempt]
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
