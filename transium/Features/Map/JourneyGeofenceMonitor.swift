//
//  JourneyGeofenceMonitor.swift
//  transium
//

import Combine
import CoreLocation

/// Registers CLCircularRegions for a journey attempt's geofences and reports back which
/// step's region the device entered, so the caller can report it via POST .../advance.
///
/// iOS caps an app at 20 concurrently monitored regions, so only the nearest 20 (by sequence)
/// are registered at a time.
@MainActor
final class JourneyGeofenceMonitor: NSObject, ObservableObject {
    // No @Published state to observe (progress is surfaced via `onRegionEntered` instead),
    // so conformance is declared explicitly rather than relying on synthesis.
    let objectWillChange = ObservableObjectPublisher()

    var onRegionEntered: ((String) -> Void)?

    private let locationManager = CLLocationManager()

    /// The regions currently registered with Core Location — i.e. actively geofenced right
    /// now, not just the ones a journey asked for (`startMonitoring` caps at 20; anything
    /// past that never made it here). Identifier is the step id (see `startMonitoring`).
    var activeRegions: [CLCircularRegion] {
        locationManager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func startMonitoring(geofences: [JourneyGeofence]) {
        stopMonitoring()

        let toMonitor = geofences.sorted { $0.sequence < $1.sequence }.prefix(20)
        for geofence in toMonitor {
            let region = CLCircularRegion(
                center: geofence.coordinate,
                radius: max(geofence.radiusMeters, 10),
                identifier: geofence.stepId
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
        }
    }

    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
}

extension JourneyGeofenceMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            onRegionEntered?(region.identifier)
        }
    }
}
