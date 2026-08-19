//
//  JourneyModels.swift
//  transium
//

import Foundation
import CoreLocation

// MARK: - Journey Overview Response (/journey/overview)

public struct JourneyResponse: Codable, Equatable, Sendable {
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

public struct JourneyResult: Codable, Equatable, Sendable {
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

public struct JourneyOverviewSummary: Codable, Equatable, Sendable {
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

public struct JourneyStep: Codable, Equatable, Sendable, Identifiable {
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

public struct JourneyLocationRef: Codable, Equatable, Sendable {
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

public struct JourneyWalkStep: Codable, Equatable, Sendable {
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

public struct JourneySegment: Codable, Equatable, Sendable, Identifiable {
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
}

// MARK: - Journey Attempt Models (/private/journey/*)

public struct JourneyAttempt: Codable, Identifiable, Sendable, Equatable {
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

public enum JourneyAttemptStepStatus: String, Codable, Sendable {
    case waiting
    case done
}

public struct JourneyAttemptStep: Codable, Identifiable, Sendable, Equatable {
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

public struct JourneySummary: Codable, Identifiable, Sendable, Equatable {
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

public struct StartJourneyRequest: Codable, Sendable {
    public let questId: String

    public init(questId: String) {
        self.questId = questId
    }
}

struct StartJourneyResponse: Codable {
    let journeyAttempt: JourneyAttempt
}

struct JourneyAttemptListResponse: Codable {
    let journeyAttempts: [JourneyAttempt]
}

public struct JourneyAttemptDetailResponse: Codable, Sendable, Equatable {
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

public struct JourneyMediaResponse: Codable, Sendable {
    public let media: MediaAsset

    public init(media: MediaAsset) {
        self.media = media
    }
}
