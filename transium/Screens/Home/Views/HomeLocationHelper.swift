//
//  HomeLocationHelper.swift
//  transium
//

import CoreLocation
import Foundation

enum HomeLocationHelper {
    static let baliFallbackLocation = CLLocation(latitude: -8.73704, longitude: 115.17570)

    static func coordinateForKelurahan(_ kelurahan: Kelurahan) -> CLLocation {
        switch kelurahan.id {
        case "7760985": // Benoa / Nusa Dua
            return CLLocation(latitude: -8.7981, longitude: 115.2185)
        case "20447626": // Ubud
            return CLLocation(latitude: -8.5069, longitude: 115.2625)
        case "20447290": // Panjer
            return CLLocation(latitude: -8.6783, longitude: 115.2312)
        case "20447300": // Dauh Puri Kaja
            return CLLocation(latitude: -8.6425, longitude: 115.2120)
        case "20447299": // Dauh Puri Kangin
            return CLLocation(latitude: -8.6578, longitude: 115.2185)
        case "20447275": // Sanur Kauh
            return CLLocation(latitude: -8.7050, longitude: 115.2500)
        case "20447277": // Sanur
            return CLLocation(latitude: -8.6882, longitude: 115.2635)
        default:
            let name = kelurahan.kelurahanName.lowercased()
            if name.contains("ubud") {
                return CLLocation(latitude: -8.5069, longitude: 115.2625)
            } else if name.contains("sanur") {
                return CLLocation(latitude: -8.6882, longitude: 115.2635)
            } else if name.contains("benoa") || name.contains("nusa dua") {
                return CLLocation(latitude: -8.7981, longitude: 115.2185)
            } else if name.contains("kuta") {
                return CLLocation(latitude: -8.7210, longitude: 115.1700)
            } else if name.contains("denpasar") || name.contains("panjer") || name.contains("dauh puri") {
                return CLLocation(latitude: -8.6705, longitude: 115.2126)
            }
            return CLLocation(latitude: -8.7021, longitude: 115.1762)
        }
    }

    static func distanceText(for group: KelurahanQuestsGroup, currentLocation: CLLocation) -> String {
        let distanceInMeters: Double
        if let dist = group.quests.first?.distanceMeters {
            distanceInMeters = dist
        } else {
            let destination = coordinateForKelurahan(group.kelurahan)
            distanceInMeters = currentLocation.distance(from: destination)
        }
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
