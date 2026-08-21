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
    case checkpoint     // A geofenced quest/photo step the app is actively watching for arrival
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
    /// The geofences POST /private/journey/go registered for this attempt — shown as subtle
    /// checkpoint markers so the user can see where the app is actively watching for arrival.
    /// Empty outside Go Mode.
    var checkpoints: [JourneyGeofence] = []
    /// True only for the live Go Mode session (not Navigation Mode's pre-Go route overview,
    /// even though both have `activeJourney != nil`) — switches the camera to a tilted,
    /// heading-oriented "third person" view that continuously follows the user along the
    /// route, instead of the flat top-down centering used everywhere else.
    var isGoMode: Bool = false
    /// True while the search sheet's pin-drop flow is active. The caller draws its own fixed
    /// pin at screen center (`centerPinIndicator`); this just reports the map's own center
    /// coordinate back via `onPinCenterChanged` as the user drags the map underneath it.
    var isPinning: Bool = false
    /// A specific coordinate to animate the camera to once — set when entering pinning mode
    /// (a picked search result, or "use my current location"), unlike `centerRequestID` this
    /// doesn't track continuous GPS updates, just a one-shot jump to wherever this points.
    var pinFocusCoordinate: CLLocationCoordinate2D?
    /// The map's live center coordinate, reported whenever it settles while `isPinning` is
    /// true — the caller debounces this into a reverse-geocode lookup.
    var onPinCenterChanged: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.compassViewPosition = .topRight
        mapView.compassView.isHidden = true
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.minimumZoomLevel = 9.0
        mapView.maximumZoomLevel = 16.5
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

        context.coordinator.attachFollowGestureObserversIfNeeded(to: mapView)

        context.coordinator.syncUserAnnotation(
            on: mapView,
            location: displayLocation,
            heading: markerHeading
        )
        
        context.coordinator.syncRouteOverlays(
            on: mapView,
            activeJourney: activeJourney,
            checkpoints: checkpoints,
            displayLocation: displayLocation,
            context: context
        )

        // Keep the Coordinator's delegate callback in sync every refresh — mirrors how
        // `geofenceMonitor.onRegionEntered` gets reassigned on the HomeScreen side elsewhere in
        // this app, since a UIViewRepresentable's closures aren't otherwise reachable from the
        // Coordinator's own delegate methods.
        context.coordinator.isPinningActive = isPinning
        context.coordinator.onPinCenterChanged = onPinCenterChanged

        if isPinning, let pinFocusCoordinate {
            let changed = context.coordinator.lastPinFocusCoordinate.map {
                abs($0.latitude - pinFocusCoordinate.latitude) > 0.00001 ||
                abs($0.longitude - pinFocusCoordinate.longitude) > 0.00001
            } ?? true
            if changed {
                context.coordinator.lastPinFocusCoordinate = pinFocusCoordinate
                mapView.setCenter(pinFocusCoordinate, zoomLevel: 16.5, animated: true)
            }
        }

        guard let displayLocation else {
            return
        }
        
        let shouldCenterForNewLocation = context.coordinator.lastCenteredCoordinate.map {
            abs($0.latitude - displayLocation.coordinate.latitude) > 0.0001 ||
            abs($0.longitude - displayLocation.coordinate.longitude) > 0.0001
        } ?? true

        let isExplicitFocusRequest = context.coordinator.lastCenterRequestID != centerRequestID

        // Entering Go Mode always starts in third-person follow, regardless of whatever
        // free-wander state (see below) was left over from an earlier trip.
        if isGoMode, !context.coordinator.wasGoMode {
            context.coordinator.isFollowing = true
        }
        context.coordinator.wasGoMode = isGoMode

        if isGoMode {
            context.coordinator.lastCenterRequestID = centerRequestID
            context.coordinator.lastCenteredCoordinate = displayLocation.coordinate
            // An explicit focus tap always re-engages following, overriding a manual wander.
            if isExplicitFocusRequest {
                context.coordinator.isFollowing = true
            }
            guard context.coordinator.isFollowing else { return }
            context.coordinator.applyThirdPersonCamera(on: mapView, location: displayLocation, deviceHeading: markerHeading)
            return
        }

        // Passive re-centering (tracking the user's dot as it moves) is suppressed once a
        // journey is active, so the camera doesn't keep fighting a manual pan/zoom while
        // reviewing the route/trip. An explicit tap on the "focus"/"locate" button
        // (`centerRequestID` bump, from Navigation Mode's journey overview) is a direct
        // request, not passive tracking, so it should always recenter on the user regardless
        // of whether a journey is active.
        if isExplicitFocusRequest || (activeJourney == nil && shouldCenterForNewLocation) {
            context.coordinator.lastCenterRequestID = centerRequestID
            context.coordinator.lastCenteredCoordinate = displayLocation.coordinate
            mapView.setCenter(
                displayLocation.coordinate,
                zoomLevel: 15.5,
                animated: true
            )
        }
    }
    
    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var lastCenterRequestID = 0
        var lastCenteredCoordinate: CLLocationCoordinate2D?
        var existingRouteSourceIds: [String] = []
        var lastSyncedJourneyId: String?
        var roadPolylineCache: [String: [CLLocationCoordinate2D]] = [:]
        private let userAnnotation = PreviewUserPointAnnotation()
        private var lastRenderedLocation: CLLocation?

        // MARK: - Pin-drop (search sheet)

        var isPinningActive = false
        var onPinCenterChanged: ((CLLocationCoordinate2D) -> Void)?
        var lastPinFocusCoordinate: CLLocationCoordinate2D?

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            guard isPinningActive else { return }
            onPinCenterChanged?(mapView.centerCoordinate)
        }

        // MARK: - Go Mode third-person camera

        /// Whether the camera should keep chasing the user (Go Mode's default). Cleared the
        /// instant the user pans/pinches/rotates the map by hand — see
        /// `attachFollowGestureObserversIfNeeded` — and re-armed either by a fresh Go Mode
        /// entry or an explicit focus-button tap (`updateUIView`).
        var isFollowing = true
        /// Tracks the isGoMode → isGoMode transition so a *fresh* entry into Go Mode always
        /// resets `isFollowing`, instead of inheriting whatever free-wander state a previous
        /// trip left behind (the Coordinator itself outlives any single trip).
        var wasGoMode = false
        /// The active route's full geometry, in travel order — used to orient the third-person
        /// camera along the road ahead rather than the device's raw compass. Rebuilt by
        /// `syncRouteOverlays` whenever the journey identity changes.
        private var routePathCoordinates: [CLLocationCoordinate2D] = []
        private var didAttachFollowGestureObservers = false

        // Matches `MLNMapView.maximumZoomLevel` (set in `makeUIView`) — anything higher would
        // just get silently clamped there anyway.
        private static let thirdPersonZoomLevel: Double = 16.5
        private static let thirdPersonPitch: CGFloat = 55
        /// How far ahead along the route to look when computing the camera's heading — short
        /// enough to hug tight turns, long enough not to jitter on GPS noise between updates.
        private static let headingLookaheadMeters: CLLocationDistance = 25

        /// Adds gesture recognizers purely to *observe* the start of a manual pan/pinch/rotate
        /// (never consuming the touch — `cancelsTouchesInView = false` plus always allowing
        /// simultaneous recognition — so MapLibre's own built-in gesture handling is untouched)
        /// and use that as the signal that the user has taken over from the follow camera.
        /// Idempotent since `updateUIView` calls this on every refresh.
        func attachFollowGestureObserversIfNeeded(to mapView: MLNMapView) {
            guard !didAttachFollowGestureObservers else { return }
            didAttachFollowGestureObservers = true

            let recognizers: [UIGestureRecognizer] = [UIPanGestureRecognizer(), UIPinchGestureRecognizer(), UIRotationGestureRecognizer()]
            for recognizer in recognizers {
                recognizer.delegate = self
                recognizer.cancelsTouchesInView = false
                recognizer.addTarget(self, action: #selector(handleUserMapGesture(_:)))
                mapView.addGestureRecognizer(recognizer)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func handleUserMapGesture(_ recognizer: UIGestureRecognizer) {
            guard recognizer.state == .began else { return }
            isFollowing = false
        }

        /// Moves the camera to a tilted, heading-oriented view centered on the user — Go
        /// Mode's own following camera, distinct from the flat top-down centering used
        /// everywhere else. Heading follows the route path ahead of the user rather than the
        /// device's raw compass: steadier (compass jitters, especially standing still) and
        /// answers "which way does the route go from here" rather than "which way is the
        /// phone physically pointed."
        func applyThirdPersonCamera(on mapView: MLNMapView, location: CLLocation, deviceHeading: CLLocationDirection) {
            let heading: CLLocationDirection
            if let ahead = pointAhead(of: location, on: routePathCoordinates, lookahead: Self.headingLookaheadMeters) {
                heading = bearing(from: location.coordinate, to: ahead)
            } else {
                heading = deviceHeading
            }

            if abs(mapView.zoomLevel - Self.thirdPersonZoomLevel) > 0.3 {
                mapView.setZoomLevel(Self.thirdPersonZoomLevel, animated: false)
            }

            let camera = mapView.camera
            camera.centerCoordinate = location.coordinate
            camera.heading = heading
            camera.pitch = Self.thirdPersonPitch
            mapView.setCamera(camera, withDuration: 0.6, animationTimingFunction: CAMediaTimingFunction(name: .linear), completionHandler: nil)
        }

        /// A point `lookahead` meters ahead of `location` along `path`: finds the nearest
        /// vertex on the path, then walks forward summing segment lengths until `lookahead` is
        /// covered (interpolating within the final segment), falling back to the path's last
        /// point if it runs out of road. Returns nil for a path too short to have a direction.
        private func pointAhead(of location: CLLocation, on path: [CLLocationCoordinate2D], lookahead: CLLocationDistance) -> CLLocationCoordinate2D? {
            guard path.count >= 2 else { return nil }

            var nearestIndex = 0
            var nearestDistance = CLLocationDistance.greatestFiniteMagnitude
            for (index, coordinate) in path.enumerated() {
                let distance = location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestIndex = index
                }
            }
            // Already at (or past) the path's last vertex — nothing ahead to point toward.
            guard nearestIndex < path.count - 1 else { return nil }

            var remaining = lookahead
            var previous = CLLocation(latitude: path[nearestIndex].latitude, longitude: path[nearestIndex].longitude)
            var index = nearestIndex + 1
            while index < path.count {
                let next = CLLocation(latitude: path[index].latitude, longitude: path[index].longitude)
                let segmentDistance = previous.distance(from: next)
                if segmentDistance >= remaining {
                    let fraction = segmentDistance > 0 ? remaining / segmentDistance : 0
                    let lat = previous.coordinate.latitude + (next.coordinate.latitude - previous.coordinate.latitude) * fraction
                    let lon = previous.coordinate.longitude + (next.coordinate.longitude - previous.coordinate.longitude) * fraction
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                remaining -= segmentDistance
                previous = next
                index += 1
            }
            // Ran out of road before covering the full lookahead — the guard above already
            // confirmed `nearestIndex` isn't the last vertex, so this is still a genuine point
            // ahead, just closer than `lookahead`.
            return path.last
        }

        /// Great-circle initial bearing (0-360°, clockwise from true north) from `from` to `to`.
        private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
            let lat1 = from.latitude * .pi / 180
            let lat2 = to.latitude * .pi / 180
            let deltaLon = (to.longitude - from.longitude) * .pi / 180
            let y = sin(deltaLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
            let radiansBearing = atan2(y, x)
            return (radiansBearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        }

        func syncUserAnnotation(
            on mapView: MLNMapView,
            location: CLLocation?,
            heading: CLLocationDirection
        ) {
            guard let location else {
                if mapView.annotations?.contains(where: { $0 === userAnnotation }) == true {
                    mapView.removeAnnotation(userAnnotation)
                }
                lastRenderedLocation = nil
                return
            }
            
            if let previousLoc = lastRenderedLocation {
                let distance = previousLoc.distance(from: location)
                if distance < 5.0 {
                    // Update only compass heading, avoid coordinate jitter
                    userAnnotation.heading = heading
                    if let userView = mapView.view(for: userAnnotation) as? PreviewUserAnnotationView {
                        userView.updateHeading(heading, animated: true)
                    }
                    return
                }
            }
            
            lastRenderedLocation = location
            userAnnotation.coordinate = location.coordinate
            userAnnotation.heading = heading
            
            if mapView.annotations?.contains(where: { $0 === userAnnotation }) != true {
                mapView.addAnnotation(userAnnotation)
            } else if let userView = mapView.view(for: userAnnotation) as? PreviewUserAnnotationView {
                userView.updateHeading(heading, animated: true)
            }
        }
        
        func syncRouteOverlays(
            on mapView: MLNMapView,
            activeJourney: JourneyResult?,
            checkpoints: [JourneyGeofence],
            displayLocation: CLLocation?,
            context: LocalBaliMapView.Context
        ) {
            // Compute identity for current journey — checkpoints included since they can arrive
            // (or clear, on cancel) independently of the route/segment shape itself.
            let currentId = activeJourney.map { "\($0.origin.lat),\($0.origin.lng)-\($0.destination.lat),\($0.destination.lng)-\($0.segments.count)-\(checkpoints.count)" }
            
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
            routePathCoordinates.removeAll()

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

            // 2.5. Add subtle checkpoint markers for every geofence the app is actively
            // watching for arrival.
            for geofence in checkpoints {
                mapView.addAnnotation(RoutePointAnnotation(coordinate: geofence.coordinate, type: .checkpoint, title: "Checkpoint"))
            }

            var addedStopCoords = Set<String>()
            
            // 3. Add segment route lines and compact stop annotations
            for (index, segment) in activeJourney.segments.enumerated() {
                // Mission entries are a quest step, not a travel leg — no from/to/geometry to
                // draw a route line for, so they're skipped on the map (they still get their
                // own card in the trip details panel).
                guard let from = segment.from, let to = segment.to else { continue }

                let sourceId = "route-source-\(index)"
                let busColor = resolveRouteColor(routeColor: segment.routeColor, routeRef: segment.routeRef)
                let fromCoord = CLLocationCoordinate2D(latitude: from.lat, longitude: from.lng)
                let toCoord = CLLocationCoordinate2D(latitude: to.lat, longitude: to.lng)

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
                        let boardKey = String(format: "%.5f,%.5f", from.lat, from.lng)
                        if !addedStopCoords.contains(boardKey) {
                            addedStopCoords.insert(boardKey)
                            mapView.addAnnotation(RoutePointAnnotation(coordinate: fromCoord, type: .boarding, title: from.name, subtitle: segment.routeRef, routeColor: busColor))
                        }
                        let alightKey = String(format: "%.5f,%.5f", to.lat, to.lng)
                        if !addedStopCoords.contains(alightKey) {
                            addedStopCoords.insert(alightKey)
                            mapView.addAnnotation(RoutePointAnnotation(coordinate: toCoord, type: .alighting, title: to.name, subtitle: segment.routeRef, routeColor: busColor))
                        }
                    }
                }

                // Get road-following polyline coordinates
                let cacheKey = "\(segment.type)-\(segment.id)"
                var coords: [CLLocationCoordinate2D] = []
                
                if let cached = roadPolylineCache[cacheKey], cached.count > 2 {
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
                    
                    // If coordinates are only 2 endpoints and segment is bus or transfer, fetch fallback
                    if coords.count <= 2 && (segment.type == "bus" || segment.type == "transfer") {
                        let stops = segment.stops
                        let transportType: MKDirectionsTransportType = (segment.type == "bus") ? .automobile : .walking
                        Task { @MainActor [weak style] in
                            let roadPoints = await self.fetchRoadPolyline(from: fromCoord, to: toCoord, intermediateStops: stops, transportType: transportType)
                            if roadPoints.count > 2 {
                                self.roadPolylineCache[cacheKey] = roadPoints
                                if let source = style?.source(withIdentifier: sourceId) as? MLNShapeSource {
                                    var pts = roadPoints
                                    source.shape = MLNPolylineFeature(coordinates: &pts, count: UInt(pts.count))
                                }
                            }
                        }
                    }
                }
                
                guard coords.count >= 2 else { continue }
                existingRouteSourceIds.append(sourceId)
                routePathCoordinates.append(contentsOf: coords)

                var pts = coords
                let polyline = MLNPolylineFeature(coordinates: &pts, count: UInt(pts.count))
                let source = MLNShapeSource(identifier: sourceId, shape: polyline, options: nil)
                style.addSource(source)
            }
            
            // Pass 1 (Bottom Layers): Add walking & transfer routes first
            for (index, segment) in activeJourney.segments.enumerated() where segment.type != "bus" {
                let sourceId = "route-source-\(index)"
                let lineLayerId = "route-line-\(index)"
                let casingLayerId = "route-casing-\(index)"
                guard let source = style.source(withIdentifier: sourceId) else { continue }
                
                let casingLayer = MLNLineStyleLayer(identifier: casingLayerId, source: source)
                casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.85))
                casingLayer.lineWidth = NSExpression(forConstantValue: 4.8)
                casingLayer.lineCap = NSExpression(forConstantValue: "round")
                casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(casingLayer)
                
                let lineLayer = MLNLineStyleLayer(identifier: lineLayerId, source: source)
                let walkColor = UIColor(red: 0.20, green: 0.50, blue: 0.98, alpha: 1.0)
                lineLayer.lineColor = NSExpression(forConstantValue: walkColor)
                lineLayer.lineWidth = NSExpression(forConstantValue: 3.2)
                lineLayer.lineCap = NSExpression(forConstantValue: "round")
                lineLayer.lineJoin = NSExpression(forConstantValue: "round")
                lineLayer.lineDashPattern = NSExpression(forConstantValue: [0.15, 1.6])
                style.addLayer(lineLayer)
            }
            
            // Pass 2 (Top Layers): Add bus routes second so they render strictly above walking lines
            for (index, segment) in activeJourney.segments.enumerated() where segment.type == "bus" {
                let sourceId = "route-source-\(index)"
                let lineLayerId = "route-line-\(index)"
                let casingLayerId = "route-casing-\(index)"
                let busColor = resolveRouteColor(routeColor: segment.routeColor, routeRef: segment.routeRef)
                guard let source = style.source(withIdentifier: sourceId) else { continue }
                
                let casingLayer = MLNLineStyleLayer(identifier: casingLayerId, source: source)
                casingLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
                casingLayer.lineWidth = NSExpression(forConstantValue: 7.5)
                casingLayer.lineCap = NSExpression(forConstantValue: "round")
                casingLayer.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(casingLayer)
                
                let lineLayer = MLNLineStyleLayer(identifier: lineLayerId, source: source)
                lineLayer.lineColor = NSExpression(forConstantValue: busColor)
                lineLayer.lineWidth = NSExpression(forConstantValue: 5.0)
                lineLayer.lineCap = NSExpression(forConstantValue: "round")
                lineLayer.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(lineLayer)
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
            if let stops = intermediateStops, stops.count >= 2 {
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
                                let legCoords = await self.fetchSingleLeg(from: p1, to: p2, transportType: transportType)
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
            
            return await fetchSingleLeg(from: start, to: end, transportType: transportType)
        }
        
        private func fetchSingleLeg(
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
                let walkReq = MKDirections.Request()
                walkReq.source = makeMapItem(coordinate: start)
                walkReq.destination = makeMapItem(coordinate: end)
                walkReq.transportType = .walking
                
                if let walkResp = try? await MKDirections(request: walkReq).calculate(),
                   let walkRoute = walkResp.routes.first {
                    var buf = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: walkRoute.polyline.pointCount)
                    walkRoute.polyline.getCoordinates(&buf, range: NSRange(location: 0, length: walkRoute.polyline.pointCount))
                    let valid = buf.filter { $0.latitude != kCLLocationCoordinate2DInvalid.latitude }
                    if valid.count >= 2 {
                        return valid
                    }
                }
            }
            
            return [start, end]
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

                case .checkpoint:
                    // Deliberately smaller/muted than the route's own points (bus stops, pins)
                    // — this just marks "the app is watching here," not a leg of the trip.
                    view.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
                    view.centerOffset = CGVector(dx: 0, dy: 0)
                    view.alpha = 0.85

                    let checkpointColor = UIColor(TransiumColor.primaryYellow)

                    let ring = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
                    ring.layer.cornerRadius = 5
                    ring.backgroundColor = .white
                    ring.layer.borderWidth = 1.5
                    ring.layer.borderColor = checkpointColor.cgColor
                    ring.layer.shadowColor = UIColor.black.cgColor
                    ring.layer.shadowOpacity = 0.15
                    ring.layer.shadowRadius = 1.5
                    ring.layer.shadowOffset = CGSize(width: 0, height: 1)

                    let dot = UIView(frame: CGRect(x: 3, y: 3, width: 4, height: 4))
                    dot.layer.cornerRadius = 2
                    dot.backgroundColor = checkpointColor
                    ring.addSubview(dot)

                    view.addSubview(ring)
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
            updateHeading(heading, animated: false)
        }
        
        func updateHeading(_ heading: CLLocationDirection, animated: Bool = true) {
            let radians = CGFloat(heading * .pi / 180)
            if animated {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                    self.arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: radians))
                }
            } else {
                arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: radians))
            }
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
