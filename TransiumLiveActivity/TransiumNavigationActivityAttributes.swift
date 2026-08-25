//
//  TransiumNavigationActivityAttributes.swift
//  transium
//

import ActivityKit
import Foundation

public struct TransiumNavigationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var routeName: String
        public var destinationName: String
        public var nextStopName: String
        public var etaText: String
        public var stopsRemainingText: String?
        public var transportType: String // "bus", "walk", "mission"
        public var progressFraction: Double // 0.0 ... 1.0
        public var isApproachingStop: Bool

        public init(
            routeName: String,
            destinationName: String,
            nextStopName: String,
            etaText: String,
            stopsRemainingText: String? = nil,
            transportType: String = "bus",
            progressFraction: Double = 0.0,
            isApproachingStop: Bool = false
        ) {
            self.routeName = routeName
            self.destinationName = destinationName
            self.nextStopName = nextStopName
            self.etaText = etaText
            self.stopsRemainingText = stopsRemainingText
            self.transportType = transportType
            self.progressFraction = progressFraction
            self.isApproachingStop = isApproachingStop
        }
    }

    public var questTitle: String
    public var questId: String
    public var attemptId: String

    public init(questTitle: String, questId: String, attemptId: String) {
        self.questTitle = questTitle
        self.questId = questId
        self.attemptId = attemptId
    }
}
