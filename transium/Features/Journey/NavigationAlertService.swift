import AudioToolbox
import CoreLocation
import Foundation
import UIKit
import UserNotifications

/// Playful haptic and audio feedback patterns for transit and navigation milestones.
public enum TransiumHapticPattern: Sendable {
    /// Playful light tap when approaching a stop or waypoint.
    case approaching
    /// Celebratory success chime when reaching/arriving at a stop or checkpoint.
    case arrived
    /// Soft tactile bump when cruising past an intermediate stop.
    case passingStop
    /// Double rigid pulse when a scenic photo keepsake spot is reached.
    case photoOp

    @MainActor
    public func play() {
        switch self {
        case .approaching:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred()
            AudioServicesPlaySystemSound(1057)

        case .arrived:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1003)

        case .passingStop:
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.prepare()
            soft.impactOccurred(intensity: 0.8)

        case .photoOp:
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred()
            AudioServicesPlaySystemSound(1075)
        }
    }
}

/// Coordinates sensory haptics and sounds when foregrounded, and phone local notifications when backgrounded.
@MainActor
public final class NavigationAlertService {
    public static let shared = NavigationAlertService()

    /// Tracks fired alert keys per journey attempt to ensure each alert fires exactly once.
    private var firedAlertKeys: Set<String> = []

    private init() {}

    /// Resets fired alert tracking when starting or canceling a journey.
    public func reset() {
        firedAlertKeys.removeAll()
    }

    /// Dispatches audio-haptics when foregrounded, or native local push notifications when backgrounded.
    public func dispatchAlert(
        key: String,
        title: String,
        message: String,
        haptic: TransiumHapticPattern = .arrived
    ) {
        guard !firedAlertKeys.contains(key) else { return }
        firedAlertKeys.insert(key)

        let isAppActive = UIApplication.shared.applicationState == .active

        if isAppActive {
            // Foreground: Sensory haptics + pleasant system sounds (no intrusive toasts)
            haptic.play()
        } else {
            // Background: System local notification banner + system sound
            PushNotificationManager.shared.postLocalNotification(
                title: title,
                body: message,
                identifier: key
            )
        }
    }

    // MARK: - Proximity Evaluation during Live Navigation

    /// Evaluates live GPS location against active transit segments and steps to trigger playful notifications.
    public func evaluateNavigationProximity(
        userLocation: CLLocation,
        journey: JourneyResult?,
        steps: [JourneyAttemptStep],
        currentSegmentIndex: Int
    ) {
        guard let journey, journey.segments.indices.contains(currentSegmentIndex) else { return }
        let segment = journey.segments[currentSegmentIndex]

        // 1. Evaluate Active Segment Stops & Waypoints
        if segment.type == "bus" {
            evaluateTransitSegment(userLocation: userLocation, segment: segment)
        } else if segment.type == "walk" || segment.type == "transfer" {
            evaluateWalkSegment(userLocation: userLocation, segment: segment)
        } else if segment.isMission {
            evaluateMissionSegment(userLocation: userLocation, segment: segment, steps: steps)
        }

        // 2. Evaluate Photo Checkpoints in Remaining Steps
        for step in steps where step.status == .waiting && step.isPhotoCheckpoint {
            guard let lat = step.lat, let lng = step.lng else { continue }
            let stepCoord = CLLocation(latitude: lat, longitude: lng)
            let distance = userLocation.distance(from: stepCoord)
            let placeName = step.name.isEmpty ? (step.description.isEmpty ? "Checkpoint" : step.description) : step.name

            if distance <= 60 && distance > 25 {
                dispatchAlert(
                    key: "approaching_photo_\(step.id)",
                    title: "Photo Spot Ahead",
                    message: "You are approaching \(placeName). Get ready to take a picture.",
                    haptic: .photoOp
                )
            }
        }
    }

    // MARK: - Private Segment Evaluators

    private func evaluateTransitSegment(userLocation: CLLocation, segment: JourneySegment) {
        let routeTitle = segment.routeRef?.truncatedAtDash ?? segment.routeName ?? "the bus"

        // Destination / Alighting Stop Proximity
        if let toStop = segment.to {
            let toLocation = CLLocation(latitude: toStop.coordinate.latitude, longitude: toStop.coordinate.longitude)
            let distance = userLocation.distance(from: toLocation)
            let stopName = toStop.name

            // Approaching Alight Stop (~120m away)
            if distance <= 120 && distance > 35 {
                dispatchAlert(
                    key: "approaching_alight_\(stopName)",
                    title: "Approaching Your Stop",
                    message: "Next stop is \(stopName) on \(routeTitle). Please prepare to hop off.",
                    haptic: .approaching
                )
            } else if distance <= 35 {
                dispatchAlert(
                    key: "arrived_alight_\(stopName)",
                    title: "Arrived at Your Stop",
                    message: "You have arrived at \(stopName). Time to get off the bus.",
                    haptic: .arrived
                )
            }
        }

        // Intermediate Stops Passed While on Bus
        if let intermediateStops = segment.stops {
            for stop in intermediateStops {
                let stopLocation = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
                let distance = userLocation.distance(from: stopLocation)
                let stopName = stop.name

                if distance <= 45 {
                    dispatchAlert(
                        key: "passed_intermediate_\(stopName)",
                        title: "Passing Through",
                        message: "Passing \(stopName) on \(routeTitle).",
                        haptic: .passingStop
                    )
                }
            }
        }
    }

    private func evaluateWalkSegment(userLocation: CLLocation, segment: JourneySegment) {
        if let toPoint = segment.to {
            let toLocation = CLLocation(latitude: toPoint.coordinate.latitude, longitude: toPoint.coordinate.longitude)
            let distance = userLocation.distance(from: toLocation)
            let pointName = toPoint.name

            if distance <= 60 && distance > 25 {
                dispatchAlert(
                    key: "approaching_walk_\(pointName)",
                    title: "Approaching Waypoint",
                    message: "A few more steps to reach \(pointName).",
                    haptic: .approaching
                )
            } else if distance <= 25 {
                dispatchAlert(
                    key: "arrived_walk_\(pointName)",
                    title: "Reached Waypoint",
                    message: "You have arrived at \(pointName).",
                    haptic: .arrived
                )
            }
        }
    }

    private func evaluateMissionSegment(
        userLocation: CLLocation,
        segment: JourneySegment,
        steps: [JourneyAttemptStep]
    ) {
        if let step = steps.attemptStep(for: segment), step.status == .waiting {
            guard let lat = step.lat, let lng = step.lng else { return }
            let stepLocation = CLLocation(latitude: lat, longitude: lng)
            let distance = userLocation.distance(from: stepLocation)
            let placeName = step.name.isEmpty ? (step.description.isEmpty ? "Mission Spot" : step.description) : step.name

            if distance <= 50 && distance > 25 {
                dispatchAlert(
                    key: "approaching_mission_\(step.id)",
                    title: "Mission Spot Ahead",
                    message: "You are close to \(placeName).",
                    haptic: .approaching
                )
            }
        }
    }
}
