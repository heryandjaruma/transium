//
//  CommonModels.swift
//  transium
//

import Foundation
import CoreLocation

// MARK: - LatLng
public nonisolated struct LatLng: Codable, Sendable, Equatable, Hashable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    public init(coordinate: CLLocationCoordinate2D) {
        self.lat = coordinate.latitude
        self.lng = coordinate.longitude
    }
}

// MARK: - MediaAsset
public nonisolated struct MediaAsset: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let mimeType: String
    public let sizeBytes: Int
    public let createdAt: Date

    public init(
        id: String,
        url: String,
        mimeType: String,
        sizeBytes: Int,
        createdAt: Date
    ) {
        self.id = id
        self.url = url
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }
}

// MARK: - Kelurahan
public nonisolated struct Kelurahan: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let kelurahanName: String
    public let kecamatanName: String

    public init(
        id: String,
        kelurahanName: String,
        kecamatanName: String
    ) {
        self.id = id
        self.kelurahanName = kelurahanName
        self.kecamatanName = kecamatanName
    }
}

// MARK: - APIErrorResponse
public nonisolated struct APIErrorResponse: Codable, Sendable {
    public let error: String

    public init(error: String) {
        self.error = error
    }
}
