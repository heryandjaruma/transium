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
    
    /// Concurrently resolves and attaches road-following geometries to all journey segments (bus, transfer, walk).
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
        // If geometry is already high resolution (e.g. walk routes from backend with > 2 points), keep it
        if segment.type == "walk" && segment.geometry.count > 2 {
            return segment
        }
        
        let stopsCount = segment.stops?.count ?? 0
        let cacheKey = "\(segment.type)-\(segment.from.lat),\(segment.from.lng)-\(segment.to.lat),\(segment.to.lng)-\(stopsCount)"
        if let cached = cache[cacheKey], cached.count > 2 {
            return segment.withGeometry(cached)
        }
        
        if segment.type == "bus" {
            let coords = await fetchRoadCoordinates(
                from: segment.from.coordinate,
                to: segment.to.coordinate,
                stops: segment.stops,
                transportType: .automobile
            )
            if coords.count > 2 {
                let geom = coords.map { [$0.longitude, $0.latitude] }
                cache[cacheKey] = geom
                return segment.withGeometry(geom)
            }
        } else if segment.type == "transfer" || segment.type == "walk" {
            let coords = await fetchRoadCoordinates(
                from: segment.from.coordinate,
                to: segment.to.coordinate,
                stops: nil,
                transportType: .walking
            )
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
        stops: [JourneyLocationRef]?,
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D] {
        // Primary Strategy: When bus stops are provided, route through each consecutive stop corridor
        if let stops = stops, stops.count >= 2 {
            var waypoints: [CLLocationCoordinate2D] = []
            for s in stops {
                let c = s.coordinate
                if let last = waypoints.last {
                    if abs(last.latitude - c.latitude) < 0.00001 && abs(last.longitude - c.longitude) < 0.00001 {
                        continue
                    }
                }
                waypoints.append(c)
            }
            
            if waypoints.count >= 2 {
                var results: [(Int, [CLLocationCoordinate2D])] = []
                await withTaskGroup(of: (Int, [CLLocationCoordinate2D]).self) { group in
                    for i in 0..<(waypoints.count - 1) {
                        let p1 = waypoints[i]
                        let p2 = waypoints[i + 1]
                        group.addTask {
                            let legCoords = await self.calculateLeg(from: p1, to: p2, transportType: transportType)
                            return (i, legCoords)
                        }
                    }
                    for await res in group {
                        results.append(res)
                    }
                }
                results.sort { $0.0 < $1.0 }
                
                var combined: [CLLocationCoordinate2D] = []
                for (_, legCoords) in results {
                    for pt in legCoords {
                        if let last = combined.last {
                            if abs(last.latitude - pt.latitude) < 0.000001 && abs(last.longitude - pt.longitude) < 0.000001 {
                                continue
                            }
                        }
                        combined.append(pt)
                    }
                }
                if combined.count > 2 {
                    return combined
                }
            }
        }
        
        // Direct start to end routing
        let directCoords = await calculateLeg(from: start, to: end, transportType: transportType)
        if directCoords.count > 2 {
            return directCoords
        }
        
        return [start, end]
    }
    
    private func calculateLeg(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D] {
        let primaryPoints = await requestDirections(from: start, to: end, transportType: transportType)
        if primaryPoints.count >= 2 {
            return primaryPoints
        }
        
        let fallbackType: MKDirectionsTransportType = (transportType == .automobile) ? .walking : .automobile
        let fallbackPoints = await requestDirections(from: start, to: end, transportType: fallbackType)
        if fallbackPoints.count >= 2 {
            return fallbackPoints
        }
        
        return [start, end]
    }
    
    private func makeMapItem(coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            return MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }
    
    private func requestDirections(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D] {
        let req = MKDirections.Request()
        req.source = makeMapItem(coordinate: start)
        req.destination = makeMapItem(coordinate: end)
        req.transportType = transportType
        
        let directions = MKDirections(request: req)
        do {
            let resp = try await directions.calculate()
            if let route = resp.routes.first {
                var buf = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
                route.polyline.getCoordinates(&buf, range: NSRange(location: 0, length: route.polyline.pointCount))
                let valid = buf.filter { $0.latitude != kCLLocationCoordinate2DInvalid.latitude }
                if valid.count >= 2 {
                    return valid
                }
            }
        } catch {
            // Failed
        }
        return []
    }
}
