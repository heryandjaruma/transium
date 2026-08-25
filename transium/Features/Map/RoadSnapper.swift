//
//  RoadSnapper.swift
//  transium
//

import CoreLocation
import Foundation
import MapLibre

enum RoadSnapper {
    /// Snaps the coordinate to the nearest road if within 20 meters.
    /// If beyond 20 meters, returns the raw coordinate unchanged.
    static func snapToRoad(
        coordinate: CLLocationCoordinate2D,
        mapView: MLNMapView,
        extraRoadPolylines: [[CLLocationCoordinate2D]] = []
    ) -> CLLocationCoordinate2D {
        var candidateSegments: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []

        // 1. Gather segments from active journey routes and cached road polylines
        for polyline in extraRoadPolylines {
            guard polyline.count >= 2 else { continue }
            for i in 0..<(polyline.count - 1) {
                candidateSegments.append((polyline[i], polyline[i + 1]))
            }
        }

        // 2. Gather segments from MapLibre rendered vector tile road layers
        let screenPoint = mapView.convert(coordinate, toPointTo: mapView)
        let hitBox = CGRect(x: screenPoint.x - 45, y: screenPoint.y - 45, width: 90, height: 90)
        let visibleFeatures = mapView.visibleFeatures(in: hitBox, styleLayerIdentifiers: ["roads", "roads-casing"])

        for feature in visibleFeatures {
            if let polylineFeature = feature as? MLNPolylineFeature {
                let count = Int(polylineFeature.pointCount)
                if count >= 2 {
                    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
                    polylineFeature.getCoordinates(&coords, range: NSRange(location: 0, length: count))
                    for i in 0..<(count - 1) {
                        candidateSegments.append((coords[i], coords[i + 1]))
                    }
                }
            } else if let multiPolyline = feature as? MLNMultiPolylineFeature {
                for subPoly in multiPolyline.polylines {
                    let count = Int(subPoly.pointCount)
                    if count >= 2 {
                        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
                        subPoly.getCoordinates(&coords, range: NSRange(location: 0, length: count))
                        for i in 0..<(count - 1) {
                            candidateSegments.append((coords[i], coords[i + 1]))
                        }
                    }
                }
            }
        }

        guard !candidateSegments.isEmpty else {
            return coordinate
        }

        let userLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDistance: CLLocationDistance = .infinity
        var closestCoordinate = coordinate

        for (a, b) in candidateSegments {
            let projected = project(point: coordinate, ontoSegmentA: a, b: b)
            let projLoc = CLLocation(latitude: projected.latitude, longitude: projected.longitude)
            let distance = userLoc.distance(from: projLoc)

            if distance < minDistance {
                minDistance = distance
                closestCoordinate = projected
            }
        }

        // Snap ONLY if within 20m of the road
        if minDistance <= 20.0 {
            return closestCoordinate
        } else {
            return coordinate
        }
    }

    /// Projects a coordinate onto the line segment AB in local flat meters
    static func project(
        point: CLLocationCoordinate2D,
        ontoSegmentA a: CLLocationCoordinate2D,
        b: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let midLat = (a.latitude + b.latitude) * 0.5 * .pi / 180.0
        let cosLat = cos(midLat)

        let metersPerDegLat = 111132.0
        let metersPerDegLng = 111320.0 * cosLat

        let bx = (b.longitude - a.longitude) * metersPerDegLng
        let by = (b.latitude - a.latitude) * metersPerDegLat
        let px = (point.longitude - a.longitude) * metersPerDegLng
        let py = (point.latitude - a.latitude) * metersPerDegLat

        let segLenSq = bx * bx + by * by
        guard segLenSq > 0.0001 else {
            return a
        }

        let t = max(0.0, min(1.0, (px * bx + py * by) / segLenSq))
        let projLat = a.latitude + t * (b.latitude - a.latitude)
        let projLng = a.longitude + t * (b.longitude - a.longitude)

        return CLLocationCoordinate2D(latitude: projLat, longitude: projLng)
    }

    /// Snaps a coordinate directly onto the nearest point of a given polyline
    static func snapToPolyline(
        coordinate: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D {
        guard polyline.count >= 2 else { return coordinate }
        var minDistance: CLLocationDistance = .infinity
        var bestCoordinate = coordinate
        let targetLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        for i in 0..<(polyline.count - 1) {
            let a = polyline[i]
            let b = polyline[i + 1]
            let projected = project(point: coordinate, ontoSegmentA: a, b: b)
            let projLoc = CLLocation(latitude: projected.latitude, longitude: projected.longitude)
            let distance = targetLoc.distance(from: projLoc)
            if distance < minDistance {
                minDistance = distance
                bestCoordinate = projected
            }
        }
        return bestCoordinate
    }
}
