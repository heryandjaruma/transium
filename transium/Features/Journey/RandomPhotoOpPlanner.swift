//
//  RandomPhotoOpPlanner.swift
//  transium
//

import CoreLocation

/// Picks 0-2 "spontaneous keepsake photo" points along the middle portion of a planned route —
/// purely a client-side nicety, unrelated to any quest action or geofence the server defines.
/// Deliberately excludes short trips, keeps points away from the very start/end, and (when
/// there are two) keeps them a reasonable distance apart from each other.
enum RandomPhotoOpPlanner {
    /// Below this total route distance, no photo op is offered at all — a short trip doesn't
    /// have room for a "spontaneous, not at the start or end" moment.
    private static let shortTripThresholdMeters: Double = 1500
    /// At/above this distance, a second photo op becomes possible (50/50) in addition to the
    /// first — below it (but still past the short-trip floor), there's exactly one.
    private static let twoOpThresholdMeters: Double = 4000
    /// How close to the route the trigger fires — deliberately tighter than a real quest
    /// checkpoint's geofence (150m), since this is meant to land near a specific spot, not a
    /// broad area.
    static let radiusMeters: Double = 80

    static func planPoints(for journey: JourneyResult) -> [CLLocationCoordinate2D] {
        let totalDistance = journey.summary.distanceMeters
        guard totalDistance >= shortTripThresholdMeters else { return [] }

        let polyline = concatenatedPolyline(from: journey)
        guard polyline.count >= 2 else { return [] }

        let wantsTwo = totalDistance >= twoOpThresholdMeters && Bool.random()

        if wantsTwo {
            // Split the middle 50% of the route into two windows so the two points land a
            // reasonable distance apart from each other, not just both floating independently
            // somewhere in the same broad middle stretch.
            let firstFraction = Double.random(in: 0.25...0.45)
            let secondFraction = Double.random(in: 0.55...0.75)
            return [firstFraction, secondFraction].compactMap { coordinate(at: $0, along: polyline) }
        }

        let fraction = Double.random(in: 0.30...0.70)
        return [coordinate(at: fraction, along: polyline)].compactMap { $0 }
    }

    private static func concatenatedPolyline(from journey: JourneyResult) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        for segment in journey.segments {
            // Mission segments have no geometry (empty array) — naturally skipped here.
            for point in segment.geometry {
                guard point.count >= 2 else { continue }
                // Geometry points are [lng, lat] (see JourneySegment.isAligned).
                points.append(CLLocationCoordinate2D(latitude: point[1], longitude: point[0]))
            }
        }
        return points
    }

    /// Walks the polyline's cumulative distance and interpolates the coordinate at `fraction`
    /// (0...1) of the total.
    private static func coordinate(at fraction: Double, along polyline: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard polyline.count >= 2 else { return polyline.first }

        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(polyline.count)
        for i in 1..<polyline.count {
            let distance = CLLocation(latitude: polyline[i - 1].latitude, longitude: polyline[i - 1].longitude)
                .distance(from: CLLocation(latitude: polyline[i].latitude, longitude: polyline[i].longitude))
            cumulative.append(cumulative[i - 1] + distance)
        }
        guard let total = cumulative.last, total > 0 else { return polyline.first }

        let target = total * fraction
        for i in 1..<cumulative.count where cumulative[i] >= target {
            let segmentStart = cumulative[i - 1]
            let segmentLength = cumulative[i] - segmentStart
            let t = segmentLength > 0 ? (target - segmentStart) / segmentLength : 0
            let a = polyline[i - 1]
            let b = polyline[i]
            return CLLocationCoordinate2D(
                latitude: a.latitude + (b.latitude - a.latitude) * t,
                longitude: a.longitude + (b.longitude - a.longitude) * t
            )
        }
        return polyline.last
    }
}
