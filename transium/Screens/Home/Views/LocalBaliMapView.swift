import SwiftUI
import MapLibre
import CoreLocation
import MapKit

// Route annotation types for journey visualizer
enum RoutePointType {
    case start
    case boarding       // User boards bus ("Use")
    case intermediate   // User passes on bus ("Pass")
    case alighting      // User exits bus ("Exit")
    case destination
}

final class RoutePointAnnotation: NSObject, MLNAnnotation {
    var coordinate: CLLocationCoordinate2D
    var type: RoutePointType
    var title: String?
    var subtitle: String?
    var routeColor: UIColor?
    
    init(
        coordinate: CLLocationCoordinate2D,
        type: RoutePointType,
        title: String? = nil,
        subtitle: String? = nil,
        routeColor: UIColor? = nil
    ) {
        self.coordinate = coordinate
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.routeColor = routeColor
        super.init()
    }
}


struct LocalBaliMapView: UIViewRepresentable {
    let displayLocation: CLLocation?
    let markerHeading: CLLocationDirection
    let centerRequestID: Int
    let activeJourney: JourneyResult?
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.compassViewPosition = .topRight
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsUserHeadingIndicator = false
        mapView.displayHeadingCalibration = false
        mapView.userTrackingMode = .none
        mapView.contentInset = UIEdgeInsets(top: 90, left: 0, bottom: 280, right: 0)
        let initialCoord = displayLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.73704, longitude: 115.17570)
        mapView.setCenter(
            initialCoord,
            zoomLevel: 15.5,
            animated: false
        )
        
        do {
            mapView.styleURL = try TransiumMapStyleFactory.makeLocalBaliStyleURL()
        } catch {
            AppToastCenter.shared.showError(
                title: "Map could not load",
                message: "The local Bali map files are missing or unavailable."
            )
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MLNMapView, context: Context) {
        let bottomInset: CGFloat = (activeJourney != nil) ? 320 : 280
        if mapView.contentInset.bottom != bottomInset {
            mapView.contentInset = UIEdgeInsets(top: 90, left: 0, bottom: bottomInset, right: 0)
        }
        
        context.coordinator.syncUserAnnotation(
            on: mapView,
            location: displayLocation,
            heading: markerHeading
        )
        
        context.coordinator.syncRouteOverlays(
            on: mapView,
            activeJourney: activeJourney,
            displayLocation: displayLocation,
            context: context
        )
        
        guard let displayLocation else {
            return
        }
        
        let shouldCenterForNewLocation = context.coordinator.lastCenteredCoordinate.map {
            abs($0.latitude - displayLocation.coordinate.latitude) > 0.0001 ||
            abs($0.longitude - displayLocation.coordinate.longitude) > 0.0001
        } ?? true
        
        // Only auto-center if no active journey path is present
        if activeJourney == nil {
            if shouldCenterForNewLocation || context.coordinator.lastCenterRequestID != centerRequestID {
                context.coordinator.lastCenterRequestID = centerRequestID
                context.coordinator.lastCenteredCoordinate = displayLocation.coordinate
                mapView.setCenter(
                    displayLocation.coordinate,
                    zoomLevel: 15.5,
                    animated: true
                )
            }
        }
    }
    
    final class Coordinator: NSObject, MLNMapViewDelegate {
        var lastCenterRequestID = 0
        var lastCenteredCoordinate: CLLocationCoordinate2D?
        var existingRouteSourceIds: [String] = []
        var lastSyncedJourneyId: String?
        var roadPolylineCache: [String: [CLLocationCoordinate2D]] = [:]
        private let userAnnotation = PreviewUserPointAnnotation()
        
        func syncUserAnnotation(
            on mapView: MLNMapView,
            location: CLLocation?,
            heading: CLLocationDirection
        ) {
            guard let location else {
                if mapView.annotations?.contains(where: { $0 === userAnnotation }) == true {
                    mapView.removeAnnotation(userAnnotation)
                }
                return
            }
            
            userAnnotation.coordinate = location.coordinate
            userAnnotation.heading = heading
            
            if mapView.annotations?.contains(where: { $0 === userAnnotation }) != true {
                mapView.addAnnotation(userAnnotation)
            }
        }
        
        func syncRouteOverlays(
            on mapView: MLNMapView,
            activeJourney: JourneyResult?,
            displayLocation: CLLocation?,
            context: LocalBaliMapView.Context
        ) {
            // Compute identity for current journey
            let currentId = activeJourney.map { "\($0.origin.lat),\($0.origin.lng)-\($0.destination.lat),\($0.destination.lng)-\($0.segments.count)" }
            
            // Skip if nothing changed
            if currentId == lastSyncedJourneyId { return }
            lastSyncedJourneyId = currentId
            
            // Remove previous route annotations
            let existingRouteAnn = mapView.annotations?.filter { $0 is RoutePointAnnotation } ?? []
            mapView.removeAnnotations(existingRouteAnn)
            
            // Remove previous route style layers and sources
            if let style = mapView.style {
                for layer in style.layers {
                    if layer.identifier.hasPrefix("route-line-") || layer.identifier.hasPrefix("route-casing-") {
                        style.removeLayer(layer)
                    }
                }
                for sourceId in existingRouteSourceIds {
                    if let source = style.source(withIdentifier: sourceId) {
                        style.removeSource(source)
                    }
                }
            }
            existingRouteSourceIds.removeAll()
            
            guard let activeJourney, let style = mapView.style else { return }
            
            let startCoord = CLLocationCoordinate2D(latitude: activeJourney.origin.lat, longitude: activeJourney.origin.lng)
            
            // 1. Add Start point annotation only if not overlapping with user location puck
            let isUserNearStart: Bool = {
                guard let userLoc = displayLocation else { return false }
                let userC = userLoc.coordinate
                return abs(userC.latitude - startCoord.latitude) < 0.0003 && abs(userC.longitude - startCoord.longitude) < 0.0003
            }()
            
            if !isUserNearStart {
                mapView.addAnnotation(RoutePointAnnotation(coordinate: startCoord, type: .start, title: "Start"))
            }
            
            // 2. Add Destination point annotation
            let destCoord = CLLocationCoordinate2D(latitude: activeJourney.destination.lat, longitude: activeJourney.destination.lng)
            mapView.addAnnotation(RoutePointAnnotation(coordinate: destCoord, type: .destination, title: "Destination"))
            
            var addedStopCoords = Set<String>()
            
            // 3. Add segment route lines and compact stop annotations
            for (index, segment) in activeJourney.segments.enumerated() {
                let sourceId = "route-source-\(index)"
                let lineLayerId = "route-line-\(index)"
                let casingLayerId = "route-casing-\(index)"
                let busColor = resolveRouteColor(routeColor: segment.routeColor, routeRef: segment.routeRef)
                let fromCoord = CLLocationCoordinate2D(latitude: segment.from.lat, longitude: segment.from.lng)
                let toCoord = CLLocationCoordinate2D(latitude: segment.to.lat, longitude: segment.to.lng)
                
                if segment.type == "bus" {
                    // Add compact stop annotations for boarding, intermediate, alighting stops
                    if let stops = segment.stops, !stops.isEmpty {
                        for (stopIndex, stop) in stops.enumerated() {
                            let coord = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)
                            let key = String(format: "%.5f,%.5f", stop.lat, stop.lng)
                            if !addedStopCoords.contains(key) {
                                addedStopCoords.insert(key)
                                let pointType: RoutePointType = (stopIndex == 0) ? .boarding : ((stopIndex == stops.count - 1) ? .alighting : .intermediate)
                                mapView.addAnnotation(RoutePointAnnotation(coordinate: coord, type: pointType, title: stop.name, subtitle: segment.routeRef, routeColor: busColor))
                            }
                        }
                    } else {
                        let boardKey = String(format: "%.5f,%.5f", segment.from.lat, segment.from.lng)
                        if !addedStopCoords.contains(boardKey) {
                            addedStopCoords.insert(boardKey)
                            mapView.addAnnotation(RoutePointAnnotation(coordinate: fromCoord, type: .boarding, title: segment.from.name, subtitle: segment.routeRef, routeColor: busColor))
                        }
                        let alightKey = String(format: "%.5f,%.5f", segment.to.lat, segment.to.lng)
                        if !addedStopCoords.contains(alightKey) {
                            addedStopCoords.insert(alightKey)
                            mapView.addAnnotation(RoutePointAnnotation(coordinate: toCoord, type: .alighting, title: segment.to.name, subtitle: segment.routeRef, routeColor: busColor))
                        }
                    }
                }
                
                // Get road-following polyline coordinates
                let cacheKey = "\(segment.type)-\(segment.id)"
                var coords: [CLLocationCoordinate2D] = []
                
                if let cached = roadPolylineCache[cacheKey] {
                    coords = cached
                } else {
                    // Initial coordinates from API geometry, steps, or stops
                    coords = parseCoordinates(from: segment.geometry)
                    if coords.count < 2, let steps = segment.steps {
                        var stepCoords: [CLLocationCoordinate2D] = []
                        for step in steps {
                            stepCoords.append(contentsOf: parseCoordinates(from: step.geometry))
                        }
                        if stepCoords.count >= 2 {
                            coords = stepCoords
                        }
                    }
                    if coords.count < 2, let stops = segment.stops, stops.count >= 2 {
                        coords = stops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                    }
                    if coords.count < 2 {
                        coords = [fromCoord, toCoord]
                    }
                    
                    // Asynchronously calculate street-following polyline for bus segments via MKDirections
                    if segment.type == "bus" {
                        let stops = segment.stops
                        Task { @MainActor [weak style] in
                            var roadPoints = await self.fetchRoadPolyline(from: fromCoord, to: toCoord, intermediateStops: stops, transportType: .automobile)
                            self.roadPolylineCache[cacheKey] = roadPoints
                            if let source = style?.source(withIdentifier: sourceId) as? MLNShapeSource {
                                source.shape = MLNPolylineFeature(coordinates: &roadPoints, count: UInt(roadPoints.count))
                            }
                        }
                    }
                }
                
                guard coords.count >= 2 else { continue }
                existingRouteSourceIds.append(sourceId)
                
                let polyline = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
                let source = MLNShapeSource(identifier: sourceId, shape: polyline, options: nil)
                style.addSource(source)
                
                if segment.type == "bus" {
                    let casingLayer = MLNLineStyleLayer(identifier: casingLayerId, source: source)
                    casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                    casingLayer.lineWidth = NSExpression(forConstantValue: 8.0)
                    casingLayer.lineCap = NSExpression(forConstantValue: "round")
                    casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(casingLayer)
                    
                    let lineLayer = MLNLineStyleLayer(identifier: lineLayerId, source: source)
                    lineLayer.lineColor = NSExpression(forConstantValue: busColor)
                    lineLayer.lineWidth = NSExpression(forConstantValue: 5.0)
                    lineLayer.lineCap = NSExpression(forConstantValue: "round")
                    lineLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(lineLayer)
                } else if segment.type == "walk" {
                    let casingLayer = MLNLineStyleLayer(identifier: casingLayerId, source: source)
                    casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                    casingLayer.lineWidth = NSExpression(forConstantValue: 6.5)
                    casingLayer.lineCap = NSExpression(forConstantValue: "round")
                    casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(casingLayer)
                    
                    let lineLayer = MLNLineStyleLayer(identifier: lineLayerId, source: source)
                    lineLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1.0))
                    lineLayer.lineWidth = NSExpression(forConstantValue: 4.5)
                    lineLayer.lineCap = NSExpression(forConstantValue: "round")
                    lineLayer.lineJoin = NSExpression(forConstantValue: "round")
                    lineLayer.lineDashPattern = NSExpression(forConstantValue: [1, 2])
                    style.addLayer(lineLayer)
                } else {
                    let casingLayer = MLNLineStyleLayer(identifier: casingLayerId, source: source)
                    casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                    casingLayer.lineWidth = NSExpression(forConstantValue: 5.5)
                    casingLayer.lineCap = NSExpression(forConstantValue: "round")
                    casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                    style.addLayer(casingLayer)
                    
                    let lineLayer = MLNLineStyleLayer(identifier: lineLayerId, source: source)
                    lineLayer.lineColor = NSExpression(forConstantValue: UIColor.systemGray)
                    lineLayer.lineWidth = NSExpression(forConstantValue: 3.5)
                    lineLayer.lineCap = NSExpression(forConstantValue: "round")
                    lineLayer.lineDashPattern = NSExpression(forConstantValue: [1, 2])
                    style.addLayer(lineLayer)
                }
            }
            
            // 4. Focus map camera on route start leg at readable street zoom level
            let startCenter = CLLocationCoordinate2D(latitude: activeJourney.origin.lat, longitude: activeJourney.origin.lng)
            DispatchQueue.main.async {
                mapView.setCenter(startCenter, zoomLevel: 14.8, animated: true)
            }
        }
        
        private func makeMapItem(coordinate: CLLocationCoordinate2D) -> MKMapItem {
            if #available(iOS 26.0, *) {
                return MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
            } else {
                return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            }
        }
        
        private func fetchRoadPolyline(
            from start: CLLocationCoordinate2D,
            to end: CLLocationCoordinate2D,
            intermediateStops: [JourneyLocationRef]?,
            transportType: MKDirectionsTransportType = .automobile
        ) async -> [CLLocationCoordinate2D] {
            var waypoints: [CLLocationCoordinate2D] = [start]
            if let stops = intermediateStops, stops.count > 2 {
                for s in stops.dropFirst().dropLast() {
                    waypoints.append(CLLocationCoordinate2D(latitude: s.lat, longitude: s.lng))
                }
            }
            waypoints.append(end)
            
            var roadCoords: [CLLocationCoordinate2D] = []
            
            for i in 0..<(waypoints.count - 1) {
                let p1 = waypoints[i]
                let p2 = waypoints[i + 1]
                
                let req = MKDirections.Request()
                req.source = makeMapItem(coordinate: p1)
                req.destination = makeMapItem(coordinate: p2)
                req.transportType = transportType
                
                let directions = MKDirections(request: req)
                do {
                    let resp = try await directions.calculate()
                    if let route = resp.routes.first {
                        var buf = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
                        route.polyline.getCoordinates(&buf, range: NSRange(location: 0, length: route.polyline.pointCount))
                        let valid = buf.filter { $0.latitude != kCLLocationCoordinate2DInvalid.latitude }
                        roadCoords.append(contentsOf: valid)
                    } else {
                        roadCoords.append(p1)
                        roadCoords.append(p2)
                    }
                } catch {
                    roadCoords.append(p1)
                    roadCoords.append(p2)
                }
            }
            
            // Filter out duplicate consecutive points
            var result: [CLLocationCoordinate2D] = []
            for c in roadCoords {
                if let last = result.last {
                    if abs(last.latitude - c.latitude) < 0.000001 && abs(last.longitude - c.longitude) < 0.000001 {
                        continue
                    }
                }
                result.append(c)
            }
            return result.count >= 2 ? result : [start, end]
        }
        
        func parseCoordinates(from geometry: [[Double]]) -> [CLLocationCoordinate2D] {
            var coords: [CLLocationCoordinate2D] = []
            for point in geometry {
                guard let coord = parseSingleCoordinate(point) else { continue }
                if let last = coords.last {
                    if abs(last.latitude - coord.latitude) < 0.000001 && abs(last.longitude - coord.longitude) < 0.000001 {
                        continue
                    }
                }
                coords.append(coord)
            }
            return coords
        }
        
        private func parseSingleCoordinate(_ point: [Double]) -> CLLocationCoordinate2D? {
            guard point.count >= 2 else { return nil }
            let val1 = point[0]
            let val2 = point[1]
            
            if (-9.0 ... -8.0).contains(val1) && (114.0 ... 116.0).contains(val2) {
                return CLLocationCoordinate2D(latitude: val1, longitude: val2)
            } else if (-9.0 ... -8.0).contains(val2) && (114.0 ... 116.0).contains(val1) {
                return CLLocationCoordinate2D(latitude: val2, longitude: val1)
            }
            
            if val1 < 0 {
                return CLLocationCoordinate2D(latitude: val1, longitude: val2)
            } else if val2 < 0 {
                return CLLocationCoordinate2D(latitude: val2, longitude: val1)
            }
            
            return nil
        }
        
        func parseColor(from hex: String?) -> UIColor {
            guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
                return UIColor(red: 0.19, green: 0.43, blue: 0.91, alpha: 1.0)
            }
            var hexSanitized = hex
            if hexSanitized.hasPrefix("#") {
                hexSanitized.removeFirst()
            }
            var rgb: UInt64 = 0
            Scanner(string: hexSanitized).scanHexInt64(&rgb)
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        }
        
        func resolveRouteColor(routeColor: String?, routeRef: String?) -> UIColor {
            if let colorHex = routeColor?.trimmingCharacters(in: .whitespacesAndNewlines), !colorHex.isEmpty {
                return parseColor(from: colorHex)
            }
            guard let ref = routeRef?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else {
                return UIColor(red: 0.19, green: 0.43, blue: 0.91, alpha: 1.0)
            }
            let baseRef = ref.components(separatedBy: "-").first?.uppercased() ?? ref.uppercased()
            switch baseRef {
            case "K1B": return parseColor(from: "#0072B2")
            case "K2B": return parseColor(from: "#0073B2")
            case "K3B": return parseColor(from: "#164C64")
            case "K4B": return parseColor(from: "#40B0A6")
            case "K5B": return parseColor(from: "#E69F00")
            case "K6B": return parseColor(from: "#57B4E9")
            case "I1":  return parseColor(from: "#05ACC1")
            case "TS1": return parseColor(from: "#019E73")
            default:    return parseColor(from: ref)
            }
        }
        
        func mapView(_ mapView: MLNMapView, viewFor annotation: any MLNAnnotation) -> MLNAnnotationView? {
            if let userAnnotation = annotation as? PreviewUserPointAnnotation {
                let reuseIdentifier = "preview-user-location"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? PreviewUserAnnotationView)
                ?? PreviewUserAnnotationView(reuseIdentifier: reuseIdentifier)
                view.configure(heading: userAnnotation.heading)
                view.layer.zPosition = 1000
                return view
            }
            
            if let routeAnn = annotation as? RoutePointAnnotation {
                let reuseIdentifier = "route-point-\(routeAnn.type)"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) ?? MLNAnnotationView(reuseIdentifier: reuseIdentifier)
                view.backgroundColor = .clear
                view.layer.zPosition = 100
                view.subviews.forEach { $0.removeFromSuperview() }
                
                switch routeAnn.type {
                case .start:
                    view.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view.centerOffset = CGVector(dx: 0, dy: 0)
                    
                    let circle = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
                    circle.layer.cornerRadius = 7
                    circle.backgroundColor = UIColor(red: 0.24, green: 0.65, blue: 0.44, alpha: 1.0)
                    circle.layer.borderWidth = 2.0
                    circle.layer.borderColor = UIColor.white.cgColor
                    circle.layer.shadowColor = UIColor.black.cgColor
                    circle.layer.shadowOpacity = 0.2
                    circle.layer.shadowRadius = 2
                    circle.layer.shadowOffset = CGSize(width: 0, height: 1)
                    
                    let innerDot = UIView(frame: CGRect(x: 4, y: 4, width: 6, height: 6))
                    innerDot.layer.cornerRadius = 3
                    innerDot.backgroundColor = .white
                    circle.addSubview(innerDot)
                    
                    view.addSubview(circle)
                    
                case .boarding:
                    view.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
                    view.centerOffset = CGVector(dx: 0, dy: 0)
                    
                    let ring = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
                    ring.layer.cornerRadius = 6
                    ring.backgroundColor = .white
                    ring.layer.borderWidth = 2.5
                    ring.layer.borderColor = (routeAnn.routeColor ?? UIColor(red: 0.24, green: 0.65, blue: 0.44, alpha: 1.0)).cgColor
                    ring.layer.shadowColor = UIColor.black.cgColor
                    ring.layer.shadowOpacity = 0.2
                    ring.layer.shadowRadius = 2
                    ring.layer.shadowOffset = CGSize(width: 0, height: 1)
                    
                    let busDot = UIView(frame: CGRect(x: 3.5, y: 3.5, width: 5, height: 5))
                    busDot.layer.cornerRadius = 2.5
                    busDot.backgroundColor = routeAnn.routeColor ?? UIColor(red: 0.24, green: 0.65, blue: 0.44, alpha: 1.0)
                    ring.addSubview(busDot)
                    
                    view.addSubview(ring)
                    
                case .intermediate:
                    view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
                    view.centerOffset = CGVector(dx: 0, dy: 0)
                    
                    let node = UIView(frame: CGRect(x: 1, y: 1, width: 6, height: 6))
                    node.layer.cornerRadius = 3
                    node.backgroundColor = .white
                    node.layer.borderWidth = 1.5
                    node.layer.borderColor = (routeAnn.routeColor ?? UIColor(red: 0.19, green: 0.43, blue: 0.91, alpha: 1.0)).cgColor
                    node.layer.shadowColor = UIColor.black.cgColor
                    node.layer.shadowOpacity = 0.15
                    node.layer.shadowRadius = 1
                    node.layer.shadowOffset = CGSize(width: 0, height: 1)
                    
                    view.addSubview(node)
                    
                case .alighting:
                    view.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
                    view.centerOffset = CGVector(dx: 0, dy: 0)
                    
                    let ring = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
                    ring.layer.cornerRadius = 6
                    ring.backgroundColor = routeAnn.routeColor ?? UIColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 1.0)
                    ring.layer.borderWidth = 2.0
                    ring.layer.borderColor = UIColor.white.cgColor
                    ring.layer.shadowColor = UIColor.black.cgColor
                    ring.layer.shadowOpacity = 0.2
                    ring.layer.shadowRadius = 2
                    ring.layer.shadowOffset = CGSize(width: 0, height: 1)
                    
                    let innerWhite = UIView(frame: CGRect(x: 3.5, y: 3.5, width: 5, height: 5))
                    innerWhite.layer.cornerRadius = 2.5
                    innerWhite.backgroundColor = .white
                    ring.addSubview(innerWhite)
                    
                    view.addSubview(ring)
                    
                case .destination:
                    view.frame = CGRect(x: 0, y: 0, width: 22, height: 26)
                    view.centerOffset = CGVector(dx: 0, dy: -13)
                    
                    let pinContainer = UIView(frame: CGRect(x: 0, y: 0, width: 22, height: 26))
                    
                    let pinHead = UIView(frame: CGRect(x: 2, y: 0, width: 18, height: 18))
                    pinHead.layer.cornerRadius = 9
                    pinHead.backgroundColor = UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
                    pinHead.layer.borderWidth = 2.0
                    pinHead.layer.borderColor = UIColor.white.cgColor
                    pinHead.layer.shadowColor = UIColor.black.cgColor
                    pinHead.layer.shadowOpacity = 0.28
                    pinHead.layer.shadowRadius = 3
                    pinHead.layer.shadowOffset = CGSize(width: 0, height: 2)
                    
                    let innerWhiteDot = UIView(frame: CGRect(x: 5, y: 5, width: 8, height: 8))
                    innerWhiteDot.layer.cornerRadius = 4
                    innerWhiteDot.backgroundColor = .white
                    pinHead.addSubview(innerWhiteDot)
                    
                    let pointerPath = UIBezierPath()
                    pointerPath.move(to: CGPoint(x: 7, y: 17))
                    pointerPath.addLine(to: CGPoint(x: 11, y: 24))
                    pointerPath.addLine(to: CGPoint(x: 15, y: 17))
                    pointerPath.close()
                    
                    let pointerShape = CAShapeLayer()
                    pointerShape.path = pointerPath.cgPath
                    pointerShape.fillColor = UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0).cgColor
                    pointerShape.strokeColor = UIColor.white.cgColor
                    pointerShape.lineWidth = 1.0
                    
                    pinContainer.layer.addSublayer(pointerShape)
                    pinContainer.addSubview(pinHead)
                    
                    view.addSubview(pinContainer)
                }
                
                return view
            }
            
            return nil
        }
    }
    
    private final class PreviewUserPointAnnotation: MLNPointAnnotation {
        var heading: CLLocationDirection = 0
    }
    
    private final class PreviewUserAnnotationView: MLNAnnotationView {
        private let outerPulseView = UIView()
        private let innerPulseView = UIView()
        private let coreView = UIView()
        private let arrowLayer = CAShapeLayer()
        
        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            frame = CGRect(origin: .zero, size: CGSize(width: 56, height: 56))
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false
            centerOffset = .zero
            scalesWithViewingDistance = false
            layer.zPosition = 1000
            
            outerPulseView.frame = CGRect(x: 2, y: 2, width: 52, height: 52)
            outerPulseView.backgroundColor = UIColor(TransiumColor.primaryBlue.opacity(0.14))
            outerPulseView.layer.cornerRadius = 26
            addSubview(outerPulseView)
            
            innerPulseView.frame = CGRect(x: 8, y: 8, width: 40, height: 40)
            innerPulseView.backgroundColor = UIColor(TransiumColor.primaryBlue.opacity(0.22))
            innerPulseView.layer.cornerRadius = 20
            addSubview(innerPulseView)
            
            coreView.frame = CGRect(x: 13, y: 13, width: 30, height: 30)
            coreView.backgroundColor = UIColor(red: 0.12, green: 0.47, blue: 0.98, alpha: 1.0)
            coreView.layer.cornerRadius = 15
            coreView.layer.borderWidth = 3.0
            coreView.layer.borderColor = UIColor.white.cgColor
            coreView.layer.shadowColor = UIColor.black.withAlphaComponent(0.28).cgColor
            coreView.layer.shadowOpacity = 1
            coreView.layer.shadowRadius = 5
            coreView.layer.shadowOffset = CGSize(width: 0, height: 2)
            addSubview(coreView)
            
            arrowLayer.fillColor = UIColor.white.cgColor
            arrowLayer.path = Self.arrowPath(in: CGRect(x: 0, y: 0, width: 14, height: 14)).cgPath
            arrowLayer.bounds = CGRect(x: 0, y: 0, width: 14, height: 14)
            arrowLayer.position = CGPoint(x: 15, y: 15)
            arrowLayer.contentsScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
            coreView.layer.addSublayer(arrowLayer)
            startPulseIfNeeded()
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            layer.zPosition = 1000
            startPulseIfNeeded()
        }
        
        func configure(heading: CLLocationDirection) {
            let radians = CGFloat(heading * .pi / 180)
            arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: radians))
        }
        
        private func startPulseIfNeeded() {
            guard outerPulseView.layer.animation(forKey: "pulse") == nil else {
                return
            }
            
            let outerScale = CABasicAnimation(keyPath: "transform.scale")
            outerScale.fromValue = 0.92
            outerScale.toValue = 1.08
            
            let outerOpacity = CABasicAnimation(keyPath: "opacity")
            outerOpacity.fromValue = 0.95
            outerOpacity.toValue = 0.45
            
            let outerGroup = CAAnimationGroup()
            outerGroup.animations = [outerScale, outerOpacity]
            outerGroup.duration = 1.8
            outerGroup.autoreverses = true
            outerGroup.repeatCount = .infinity
            outerGroup.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            outerGroup.isRemovedOnCompletion = false
            outerPulseView.layer.add(outerGroup, forKey: "pulse")
            
            let innerScale = CABasicAnimation(keyPath: "transform.scale")
            innerScale.fromValue = 0.96
            innerScale.toValue = 1.04
            
            let innerOpacity = CABasicAnimation(keyPath: "opacity")
            innerOpacity.fromValue = 0.9
            innerOpacity.toValue = 0.68
            
            let innerGroup = CAAnimationGroup()
            innerGroup.animations = [innerScale, innerOpacity]
            innerGroup.duration = 1.8
            innerGroup.autoreverses = true
            innerGroup.repeatCount = .infinity
            innerGroup.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            innerGroup.isRemovedOnCompletion = false
            innerPulseView.layer.add(innerGroup, forKey: "innerPulse")
        }
        
        private static func arrowPath(in rect: CGRect) -> UIBezierPath {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 7.0, y: 2.0))
            path.addLine(to: CGPoint(x: 12.0, y: 12.0))
            path.addLine(to: CGPoint(x: 7.0, y: 9.5))
            path.addLine(to: CGPoint(x: 2.0, y: 12.0))
            path.close()
            return path
        }
    }
    
}
extension CLLocationCoordinate2D {
    var isWithinBaliRegion: Bool {
        (-8.95 ... -8.05).contains(latitude) && (114.4 ... 115.8).contains(longitude)
    }
}
