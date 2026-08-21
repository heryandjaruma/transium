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
    public let type: String?
    public let mimeType: String?
    public let sizeBytes: Int?
    public let createdAt: String?
    public let alt: String?
    public let copyright: String?

    public init(
        id: String,
        url: String,
        type: String? = nil,
        mimeType: String? = nil,
        sizeBytes: Int? = nil,
        createdAt: String? = nil,
        alt: String? = nil,
        copyright: String? = nil
    ) {
        self.id = id
        self.url = url
        self.type = type
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.alt = alt
        self.copyright = copyright
    }
}

// MARK: - Kelurahan
public nonisolated struct Kelurahan: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let kelurahanName: String
    public let kecamatanName: String
    public let description: String?
    public let category: String?
    public let thumbnails: [MediaAsset]

    public init(
        id: String,
        kelurahanName: String,
        kecamatanName: String,
        description: String? = nil,
        category: String? = nil,
        thumbnails: [MediaAsset] = []
    ) {
        self.id = id
        self.kelurahanName = kelurahanName
        self.kecamatanName = kecamatanName
        self.description = description
        self.category = category
        self.thumbnails = thumbnails
    }
}

// MARK: - APIErrorResponse
public nonisolated struct APIErrorResponse: Codable, Sendable {
    public let error: String

    public init(error: String) {
        self.error = error
    }
}
