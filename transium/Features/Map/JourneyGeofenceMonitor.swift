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
///
/// Region monitoring needs `.authorizedAlways` to reliably deliver entry events — with only
/// `.authorizedWhenInUse`, `CLLocationManager.startMonitoring(for:)` frequently just silently
/// does nothing. `startMonitoring(geofences:)` requests the "Always" upgrade itself and defers
/// actually registering regions until that's granted (or falls back to trying anyway on a
/// plain "when in use" grant, since that's still better than nothing).
@MainActor
final class JourneyGeofenceMonitor: NSObject, ObservableObject {
    // No @Published state to observe (progress is surfaced via `onRegionEntered` instead),
    // so conformance is declared explicitly rather than relying on synthesis.
    let objectWillChange = ObservableObjectPublisher()

    var onRegionEntered: ((String) -> Void)?

    private let locationManager = CLLocationManager()

    /// Set by `startMonitoring` when authorization isn't sufficient yet — picked back up by
    /// `locationManagerDidChangeAuthorization` once the user responds to the permission prompt.
    private var pendingGeofences: [JourneyGeofence]?

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

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("JourneyGeofenceMonitor: region monitoring isn't available on this device.")
            return
        }

        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            registerRegions(for: geofences)
        case .authorizedWhenInUse, .notDetermined:
            // Register anyway — "when in use" region monitoring is unreliable but not
            // guaranteed to fail — while asking for the "Always" upgrade in parallel so a
            // later re-entry (or the rest of this session, once granted) works properly.
            registerRegions(for: geofences)
            pendingGeofences = geofences
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("JourneyGeofenceMonitor: location access denied/restricted, can't monitor geofences.")
        @unknown default:
            break
        }
    }

    func stopMonitoring() {
        pendingGeofences = nil
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    private func registerRegions(for geofences: [JourneyGeofence]) {
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
        print("JourneyGeofenceMonitor: registered \(toMonitor.count) region(s).")
    }
}

extension JourneyGeofenceMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("JourneyGeofenceMonitor: entered region \(region.identifier)")
        Task { @MainActor in
            onRegionEntered?(region.identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("JourneyGeofenceMonitor: monitoring failed for region \(region?.identifier ?? "?") — \(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let pendingGeofences, manager.authorizationStatus == .authorizedAlways else { return }
            self.pendingGeofences = nil
            // Re-register now that we actually have reliable monitoring — the earlier
            // when-in-use attempt may not have delivered anything.
            registerRegions(for: pendingGeofences)
        }
    }
}
