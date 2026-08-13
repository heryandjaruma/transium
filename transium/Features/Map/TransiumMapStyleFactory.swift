//
//  TransiumMapStyleFactory.swift
//  transium
//

import Foundation

enum TransiumMapStyleFactory {
    enum StyleError: LocalizedError {
        case missingPMTiles(String)
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .missingPMTiles(let name):
                "Missing bundled map resource: \(name).pmtiles"
            case .writeFailed:
                "The local map style could not be prepared."
            }
        }
    }

    static func makeLocalBaliStyleURL() throws -> URL {
        let basemapURL = try pmtilesURL(named: "bali_basemap")
        let transitURL = try pmtilesURL(named: "bali_transit")
        let styleJSON = localBaliStyleJSON(
            basemapURL: basemapURL,
            transitURL: transitURL
        )
        let styleURL = FileManager.default.temporaryDirectory
            .appending(path: "transium-bali-map-style.json")

        do {
            try styleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            return styleURL
        } catch {
            throw StyleError.writeFailed
        }
    }

    private static func pmtilesURL(named name: String) throws -> URL {
        if let url = Bundle.main.url(forResource: name, withExtension: "pmtiles") {
            return url
        }

        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "pmtiles",
            subdirectory: "Resources/Maps"
        ) {
            return url
        }

        throw StyleError.missingPMTiles(name)
    }

    private static func localBaliStyleJSON(basemapURL: URL, transitURL: URL) -> String {
        """
        {
          "version": 8,
          "name": "Transium Local Bali",
          "center": [115.1889, -8.4095],
          "zoom": 9.35,
          "pitch": 0,
          "bearing": 0,
          "sources": {
            "bali-basemap": {
              "type": "vector",
              "url": "\(pmtilesStyleURL(for: basemapURL))",
              "minzoom": 0,
              "maxzoom": 14,
              "attribution": "Transium local map data"
            },
            "bali-transit": {
              "type": "vector",
              "url": "\(pmtilesStyleURL(for: transitURL))",
              "minzoom": 0,
              "maxzoom": 14,
              "attribution": "Transium local transit data"
            }
          },
          "layers": [
            {
              "id": "background",
              "type": "background",
              "paint": { "background-color": "#2F6FEA" }
            },
            {
              "id": "land",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "land",
              "paint": { "fill-color": "#F7E7B0" }
            },
            {
              "id": "vegetation",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "vegetation",
              "paint": {
                "fill-color": "#7CCB7B",
                "fill-opacity": 0.72
              }
            },
            {
              "id": "water",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "water",
              "paint": { "fill-color": "#6BBCEB" }
            },
            {
              "id": "streams",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "streams",
              "paint": {
                "line-color": "#58A9DA",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.55, 13, 1.45],
                "line-opacity": 0.84
              }
            },
            {
              "id": "kelurahan-boundaries",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "kelurahan",
              "paint": {
                "line-color": "#FFFFFF",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.2, 13, 0.9],
                "line-opacity": 0.38
              }
            },
            {
              "id": "kecamatan-boundaries",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "kecamatan",
              "paint": {
                "line-color": "#D59B35",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.55, 13, 1.4],
                "line-opacity": 0.68
              }
            },
            {
              "id": "roads-casing",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "roads",
              "paint": {
                "line-color": "#C98F3A",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 1.0, 13, 4.0],
                "line-opacity": 0.55
              }
            },
            {
              "id": "roads",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "roads",
              "paint": {
                "line-color": "#FFF7E8",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.55, 13, 2.7],
                "line-opacity": 0.92
              }
            },
            {
              "id": "bus-routes-casing",
              "type": "line",
              "source": "bali-transit",
              "source-layer": "bus_routes",
              "paint": {
                "line-color": "#093A96",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 2.6, 13, 5.6],
                "line-opacity": 0.46
              }
            },
            {
              "id": "bus-routes",
              "type": "line",
              "source": "bali-transit",
              "source-layer": "bus_routes",
              "paint": {
                "line-color": "#1E66F5",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 1.4, 13, 3.4],
                "line-opacity": 0.94
              }
            },
            {
              "id": "bus-stops-halo",
              "type": "circle",
              "source": "bali-transit",
              "source-layer": "bus_stops",
              "paint": {
                "circle-radius": ["interpolate", ["linear"], ["zoom"], 9, 2.0, 13, 6.8],
                "circle-color": "#FFFFFF",
                "circle-opacity": 0.88
              }
            },
            {
              "id": "bus-stops",
              "type": "circle",
              "source": "bali-transit",
              "source-layer": "bus_stops",
              "paint": {
                "circle-radius": ["interpolate", ["linear"], ["zoom"], 9, 1.1, 13, 4.2],
                "circle-color": "#FFB327",
                "circle-stroke-color": "#7A4B00",
                "circle-stroke-width": 0.7
              }
            }
          ]
        }
        """
    }

    private static func pmtilesStyleURL(for fileURL: URL) -> String {
        "pmtiles://\(fileURL.absoluteString)"
    }
}
