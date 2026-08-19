//
//  RoadGeometryResolver.swift
//  transium
//

import CoreLocation
import Foundation
import MapKit

public actor RoadGeometryResolver {
    public static let shared = RoadGeometryResolver()
    
    private var cache: [String: [[Double]]] = [:]
    
    public init() {}
    
    /// Concurrently resolves and attaches road-following geometries to all journey segments.
    public func resolveJourneyGeometries(_ journey: JourneyResult) async -> JourneyResult {
        var resolvedSegments: [JourneySegment] = []
        
        await withTaskGroup(of: (Int, JourneySegment).self) { group in
            for (index, segment) in journey.segments.enumerated() {
                group.addTask {
                    let resolved = await self.resolveSegmentGeometry(segment)
                    return (index, resolved)
                }
            }
            
            var indexedSegments: [(Int, JourneySegment)] = []
            for await item in group {
                indexedSegments.append(item)
            }
            indexedSegments.sort { $0.0 < $1.0 }
            resolvedSegments = indexedSegments.map { $0.1 }
        }
        
        return JourneyResult(
            origin: journey.origin,
            destination: journey.destination,
            summary: journey.summary,
            segments: resolvedSegments,
            steps: journey.steps
        )
    }
    
    public func resolveSegmentGeometry(_ segment: JourneySegment) async -> JourneySegment {
        // If geometry is already high resolution (e.g. walk routes with > 3 points), keep it
        if segment.type == "walk" && segment.geometry.count >= 3 {
            return segment
        }
        
        if segment.type == "bus" {
            let cacheKey = "bus-\(segment.from.lat),\(segment.from.lng)-\(segment.to.lat),\(segment.to.lng)"
            if let cached = cache[cacheKey], cached.count > 2 {
                return segment.withGeometry(cached)
            }
            
            let coords = await fetchRoadCoordinates(from: segment.from.coordinate, to: segment.to.coordinate, stops: segment.stops)
            if coords.count > 2 {
                let geom = coords.map { [$0.longitude, $0.latitude] }
                cache[cacheKey] = geom
                return segment.withGeometry(geom)
            }
        }
        
        return segment
    }
    
    private func fetchRoadCoordinates(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        stops: [JourneyLocationRef]?
    ) async -> [CLLocationCoordinate2D] {
        // Strategy 1: Direct route calculation from start boarding stop to end alighting stop
        let directCoords = await calculateLeg(from: start, to: end)
        if directCoords.count > 2 {
            return directCoords
        }
        
        // Strategy 2: If direct failed and stops exist, attempt waypoint routing
        if let stops = stops, stops.count >= 2 {
            var waypoints: [CLLocationCoordinate2D] = [start]
            for s in stops.dropFirst().dropLast() {
                waypoints.append(s.coordinate)
            }
            waypoints.append(end)
            
            var collected: [CLLocationCoordinate2D] = []
            for i in 0..<(waypoints.count - 1) {
                let p1 = waypoints[i]
                let p2 = waypoints[i + 1]
                let subLeg = await calculateLeg(from: p1, to: p2)
                for pt in subLeg {
                    if let last = collected.last {
                        if abs(last.latitude - pt.latitude) < 0.000001 && abs(last.longitude - pt.longitude) < 0.000001 {
                            continue
                        }
                    }
                    collected.append(pt)
                }
            }
            if collected.count > 2 {
                return collected
            }
        }
        
        return [start, end]
    }
    
    private func calculateLeg(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D] {
        // Try automobile first
        let autoPoints = await requestDirections(from: start, to: end, transportType: .automobile)
        if autoPoints.count > 2 {
            return autoPoints
        }
        
        // Fallback to walking directions if driving route has restricted roads
        let walkPoints = await requestDirections(from: start, to: end, transportType: .walking)
        if walkPoints.count > 2 {
            return walkPoints
        }
        
        return [start, end]
    }
    
    private func requestDirections(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D] {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        req.transportType = transportType
        
        let directions = MKDirections(request: req)
        do {
            let resp = try await directions.calculate()
            if let route = resp.routes.first {
                var buf = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
                route.polyline.getCoordinates(&buf, range: NSRange(location: 0, length: route.polyline.pointCount))
                let valid = buf.filter { $0.latitude != kCLLocationCoordinate2DInvalid.latitude }
                if valid.count > 2 {
                    return valid
                }
            }
        } catch {
            // Failed
        }
        return []
    }
}
