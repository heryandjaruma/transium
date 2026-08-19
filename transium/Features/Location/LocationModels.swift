//
//  LocationModels.swift
//  transium
//

import Foundation
import CoreLocation

// MARK: - AutocompleteSuggestion
public nonisolated struct AutocompleteSuggestion: Codable, Sendable, Equatable, Hashable {
    public let label: String
    public let sublabel: String?
    public let lat: Double?
    public let lng: Double?
    public let resolveToken: String?

    public init(
        label: String,
        sublabel: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        resolveToken: String? = nil
    ) {
        self.label = label
        self.sublabel = sublabel
        self.lat = lat
        self.lng = lng
        self.resolveToken = resolveToken
    }

    public var hasCoordinates: Bool {
        lat != nil && lng != nil
    }

    public var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lng = lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - PlaceSuggestion
public nonisolated struct PlaceSuggestion: Codable, Sendable, Equatable, Hashable {
    public let label: String
    public let sublabel: String?
    public let lat: Double
    public let lng: Double

    public init(
        label: String,
        sublabel: String? = nil,
        lat: Double,
        lng: Double
    ) {
        self.label = label
        self.sublabel = sublabel
        self.lat = lat
        self.lng = lng
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - GeocodeSource
public nonisolated enum GeocodeSource: String, Codable, Sendable {
    case apple
    case osm
}

// MARK: - GeocodeResult
public nonisolated struct GeocodeResult: Codable, Sendable, Equatable {
    public let results: [PlaceSuggestion]
    public let source: GeocodeSource

    public init(results: [PlaceSuggestion], source: GeocodeSource) {
        self.results = results
        self.source = source
    }
}

// MARK: - Response Wrappers
nonisolated struct AutocompleteSearchResponse: Codable {
    let results: [AutocompleteSuggestion]
}

nonisolated struct PlaceResolveResponse: Codable {
    let results: [PlaceSuggestion]
}
