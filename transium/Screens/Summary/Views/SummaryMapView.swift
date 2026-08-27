//
//  SummaryMapView.swift
//  transium
//

import CoreLocation
import MapKit
import MapLibre
import SwiftUI

/// Renders a dynamic vector map snapshot of the user's completed journey route following real road geometry.
struct SummaryMapView: UIViewRepresentable {
    let journey: JourneyResult?
    var path: [JourneyPathPoint] = []

    func makeCoordinator() -> Coordinator {
        Coordinator(journey: journey, path: path)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.compassView.isHidden = true
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.isUserInteractionEnabled = false
        mapView.showsUserLocation = false
        mapView.showsUserHeadingIndicator = false
        mapView.delegate = context.coordinator

        let defaultCenter = CLLocationCoordinate2D(latitude: -8.690, longitude: 115.220)
        mapView.setCenter(defaultCenter, zoomLevel: 12, animated: false)

        do {
            mapView.styleURL = try TransiumMapStyleFactory.makeLocalBaliStyleURL()
        } catch {
            // Style will fallback if unavailable
        }

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.journey = journey
        context.coordinator.path = path
        context.coordinator.resolveAndRenderOverlays(on: mapView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var journey: JourneyResult?
        var path: [JourneyPathPoint] = []

        private var addedSourceIds: [String] = []
        private var isResolvingRoads = false

        init(journey: JourneyResult?, path: [JourneyPathPoint]) {
            self.journey = journey
            self.path = path
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            resolveAndRenderOverlays(on: mapView)
        }

        func resolveAndRenderOverlays(on mapView: MLNMapView) {
            renderOverlays(on: mapView)

            guard let journey, !isResolvingRoads, needsRoadResolution(journey) else { return }
            isResolvingRoads = true

            Task { @MainActor [weak self, weak mapView] in
                guard let self, let mapView else { return }
                let resolved = await RoadGeometryResolver.shared.resolveJourneyGeometries(journey)
                self.journey = resolved
                self.isResolvingRoads = false
                self.renderOverlays(on: mapView)
            }
        }

        private func needsRoadResolution(_ journey: JourneyResult) -> Bool {
            for segment in journey.segments {
                if (segment.type == "bus" || segment.type == "transfer" || segment.type == "walk") && segment.geometry.count <= 2 {
                    return true
                }
            }
            return false
        }

        func renderOverlays(on mapView: MLNMapView) {
            guard let style = mapView.style else { return }

            // Clear existing
            if let annotations = mapView.annotations {
                mapView.removeAnnotations(annotations)
            }
            for sourceId in addedSourceIds {
                let lineId = "\(sourceId)-line"
                let casingId = "\(sourceId)-casing"
                let innerId = "\(sourceId)-inner"
                if let layer = style.layer(withIdentifier: casingId) { style.removeLayer(layer) }
                if let layer = style.layer(withIdentifier: innerId) { style.removeLayer(layer) }
                if let layer = style.layer(withIdentifier: lineId) { style.removeLayer(layer) }
                if let source = style.source(withIdentifier: sourceId) { style.removeSource(source) }
            }
            addedSourceIds.removeAll()

            var allCoordinates: [CLLocationCoordinate2D] = []
            var startPinCoord: CLLocationCoordinate2D?
            var destPinCoord: CLLocationCoordinate2D?

            // 1. Draw from Journey Result
            if let journey {
                let startCoord = CLLocationCoordinate2D(latitude: journey.origin.lat, longitude: journey.origin.lng)
                let destCoord = CLLocationCoordinate2D(latitude: journey.destination.lat, longitude: journey.destination.lng)

                startPinCoord = startCoord
                destPinCoord = destCoord
                allCoordinates.append(contentsOf: [startCoord, destCoord])

                for (idx, segment) in journey.segments.enumerated() {
                    var segmentCoords: [CLLocationCoordinate2D] = []
                    if let steps = segment.steps, !steps.isEmpty {
                        for step in steps {
                            segmentCoords.append(contentsOf: parseCoordinates(step.geometry))
                        }
                    } else if !segment.geometry.isEmpty {
                        segmentCoords.append(contentsOf: parseCoordinates(segment.geometry))
                    } else if let stops = segment.stops, stops.count >= 2 {
                        segmentCoords = stops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                    } else if let from = segment.from, let to = segment.to {
                        segmentCoords = [
                            CLLocationCoordinate2D(latitude: from.lat, longitude: from.lng),
                            CLLocationCoordinate2D(latitude: to.lat, longitude: to.lng)
                        ]
                    }

                    guard segmentCoords.count >= 2 else { continue }
                    allCoordinates.append(contentsOf: segmentCoords)

                    let sourceId = "summary-seg-\(idx)"
                    addedSourceIds.append(sourceId)

                    var pts = segmentCoords
                    let polyline = MLNPolylineFeature(coordinates: &pts, count: UInt(pts.count))
                    let source = MLNShapeSource(identifier: sourceId, shape: polyline, options: nil)
                    style.addSource(source)

                    let casingLayer = MLNLineStyleLayer(identifier: "\(sourceId)-casing", source: source)
                    casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                    casingLayer.lineWidth = NSExpression(forConstantValue: 5.5)
                    casingLayer.lineCap = NSExpression(forConstantValue: "round")
                    casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(casingLayer)

                    let isBus = (segment.type == "bus")
                    let lineColor = isBus
                        ? UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1.0)
                        : UIColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1.0)

                    let lineLayer = MLNLineStyleLayer(identifier: "\(sourceId)-line", source: source)
                    lineLayer.lineColor = NSExpression(forConstantValue: lineColor)
                    lineLayer.lineWidth = NSExpression(forConstantValue: isBus ? 4.0 : 3.2)
                    lineLayer.lineCap = NSExpression(forConstantValue: "round")
                    lineLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(lineLayer)
                }
            } else if !path.isEmpty {
                // 2. Draw from GPS recorded Path
                let sortedPath = path.sorted(by: { $0.sequence < $1.sequence })
                let pathCoords = sortedPath.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                allCoordinates.append(contentsOf: pathCoords)

                startPinCoord = pathCoords.first
                destPinCoord = pathCoords.last

                if pathCoords.count >= 2 {
                    let sourceId = "summary-path-0"
                    addedSourceIds.append(sourceId)

                    var pts = pathCoords
                    let polyline = MLNPolylineFeature(coordinates: &pts, count: UInt(pts.count))
                    let source = MLNShapeSource(identifier: sourceId, shape: polyline, options: nil)
                    style.addSource(source)

                    let casingLayer = MLNLineStyleLayer(identifier: "\(sourceId)-casing", source: source)
                    casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                    casingLayer.lineWidth = NSExpression(forConstantValue: 5.5)
                    casingLayer.lineCap = NSExpression(forConstantValue: "round")
                    style.addLayer(casingLayer)

                    let lineLayer = MLNLineStyleLayer(identifier: "\(sourceId)-line", source: source)
                    lineLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1.0))
                    lineLayer.lineWidth = NSExpression(forConstantValue: 4.0)
                    lineLayer.lineCap = NSExpression(forConstantValue: "round")
                    style.addLayer(lineLayer)
                }
            }

            // 3. Draw Start & Destination Pins ON TOP of all lines
            if let start = startPinCoord {
                let startSourceId = "summary-pin-start"
                addedSourceIds.append(startSourceId)

                let startFeature = MLNPointFeature()
                startFeature.coordinate = start
                let startSource = MLNShapeSource(identifier: startSourceId, features: [startFeature], options: nil)
                style.addSource(startSource)

                let casingLayer = MLNCircleStyleLayer(identifier: "\(startSourceId)-casing", source: startSource)
                casingLayer.circleRadius = NSExpression(forConstantValue: 10.0)
                casingLayer.circleColor = NSExpression(forConstantValue: UIColor.white)
                style.addLayer(casingLayer)

                let innerLayer = MLNCircleStyleLayer(identifier: "\(startSourceId)-inner", source: startSource)
                innerLayer.circleRadius = NSExpression(forConstantValue: 7.0)
                innerLayer.circleColor = NSExpression(forConstantValue: UIColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 1.0))
                style.addLayer(innerLayer)
            }

            if let dest = destPinCoord {
                let destSourceId = "summary-pin-dest"
                addedSourceIds.append(destSourceId)

                let destFeature = MLNPointFeature()
                destFeature.coordinate = dest
                let destSource = MLNShapeSource(identifier: destSourceId, features: [destFeature], options: nil)
                style.addSource(destSource)

                let casingLayer = MLNCircleStyleLayer(identifier: "\(destSourceId)-casing", source: destSource)
                casingLayer.circleRadius = NSExpression(forConstantValue: 10.0)
                casingLayer.circleColor = NSExpression(forConstantValue: UIColor.white)
                style.addLayer(casingLayer)

                let innerLayer = MLNCircleStyleLayer(identifier: "\(destSourceId)-inner", source: destSource)
                innerLayer.circleRadius = NSExpression(forConstantValue: 7.0)
                innerLayer.circleColor = NSExpression(forConstantValue: UIColor(red: 0.09, green: 0.69, blue: 0.36, alpha: 1.0))
                style.addLayer(innerLayer)
            }

            // Fit Bounds
            if allCoordinates.count >= 2 {
                var minLat = allCoordinates[0].latitude
                var maxLat = allCoordinates[0].latitude
                var minLng = allCoordinates[0].longitude
                var maxLng = allCoordinates[0].longitude

                for c in allCoordinates {
                    minLat = min(minLat, c.latitude)
                    maxLat = max(maxLat, c.latitude)
                    minLng = min(minLng, c.longitude)
                    maxLng = max(maxLng, c.longitude)
                }

                let latMargin = max(0.006, (maxLat - minLat) * 0.18)
                let lngMargin = max(0.006, (maxLng - minLng) * 0.18)

                let sw = CLLocationCoordinate2D(latitude: minLat - latMargin, longitude: minLng - lngMargin)
                let ne = CLLocationCoordinate2D(latitude: maxLat + latMargin, longitude: maxLng + lngMargin)
                let bounds = MLNCoordinateBounds(sw: sw, ne: ne)

                mapView.setVisibleCoordinateBounds(
                    bounds,
                    edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                    animated: false,
                    completionHandler: nil
                )
            }
        }

        private func parseCoordinates(_ geometry: [[Double]]) -> [CLLocationCoordinate2D] {
            var coords: [CLLocationCoordinate2D] = []
            for point in geometry {
                guard point.count >= 2 else { continue }
                let val1 = point[0]
                let val2 = point[1]
                let coord: CLLocationCoordinate2D
                if (-9.0 ... -8.0).contains(val1) && (114.0 ... 116.0).contains(val2) {
                    coord = CLLocationCoordinate2D(latitude: val1, longitude: val2)
                } else if (114.0 ... 116.0).contains(val1) && (-9.0 ... -8.0).contains(val2) {
                    coord = CLLocationCoordinate2D(latitude: val2, longitude: val1)
                } else {
                    coord = CLLocationCoordinate2D(latitude: val1, longitude: val2)
                }
                coords.append(coord)
            }
            return coords
        }
    }
}
