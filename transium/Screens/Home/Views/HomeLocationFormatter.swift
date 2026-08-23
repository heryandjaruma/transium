//
//  HomeLocationFormatter.swift
//  transium
//

import CoreLocation
import Foundation

enum HomeLocationFormatter {
    static let baliFallbackLocation = CLLocation(latitude: -8.73704, longitude: 115.17570)

    static func distanceText(for group: AreaQuestsGroup, currentLocation: CLLocation) -> String {
        let destination = CLLocation(latitude: group.area.lat, longitude: group.area.lng)
        let distanceInMeters = group.quests.first?.distanceMeters ?? currentLocation.distance(from: destination)
        let km = distanceInMeters / 1000.0
        
        if km < 1.0 {
            let roundedMeters = max(50, Int(round(distanceInMeters / 50.0)) * 50)
            return "\(roundedMeters) m"
        } else if km < 10.0 {
            return String(format: "%.1f km", km)
        } else {
            return "\(Int(round(km))) km"
        }
    }
}
