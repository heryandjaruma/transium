//
//  LocationStore.swift
//  transium
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationStore: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var currentHeading: CLLocationDirection = 0

    private let locationManager = CLLocationManager()

    override init() {
        authorizationStatus = locationManager.authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = 1.0
        
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }

    // MARK: Important Flow - Request User Location

    func requestCurrentLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            locationManager.requestLocation()
        case .denied, .restricted:
            AppToastCenter.shared.showWarning(
                title: "Location is off",
                message: "Enable location access in Settings to show where you are on the map."
            )
        @unknown default:
            AppToastCenter.shared.showWarning(
                title: "Location unavailable",
                message: "We could not check location permission on this device."
            )
        }
    }
}

extension LocationStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            currentLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            currentHeading = heading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            AppToastCenter.shared.showWarning(
                title: "Location not found",
                message: "Move to an open area or try again in a moment."
            )
        }
    }
}
