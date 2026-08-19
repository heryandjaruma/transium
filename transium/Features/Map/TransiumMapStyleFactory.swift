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
          "center": [115.1757, -8.7370],
          "zoom": 15.5,
          "pitch": 0,
          "bearing": 0,
          "sources": {
            "bali-basemap": {
              "type": "vector",
              "url": "\(pmtilesStyleURL(for: basemapURL))",
              "minzoom": 0,
              "maxzoom": 18,
              "attribution": "Transium local map data"
            },
            "bali-transit": {
              "type": "vector",
              "url": "\(pmtilesStyleURL(for: transitURL))",
              "minzoom": 0,
              "maxzoom": 18,
              "attribution": "Transium local transit data"
            }
          },
          "layers": [
            {
              "id": "background",
              "type": "background",
              "paint": { "background-color": "#99D1F4" }
            },
            {
              "id": "land",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "land",
              "paint": { "fill-color": "#EDEDED" }
            },
            {
              "id": "vegetation",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "vegetation",
              "paint": {
                "fill-color": "#94C77E",
                "fill-opacity": 0.62
              }
            },
            {
              "id": "water",
              "type": "fill",
              "source": "bali-basemap",
              "source-layer": "water",
              "paint": { "fill-color": "#86C8F1" }
            },
            {
              "id": "streams",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "streams",
              "paint": {
                "line-color": "#A7D4EE",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.28, 13, 1.0],
                "line-opacity": 0.7
              }
            },
            {
              "id": "kelurahan-boundaries",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "kelurahan",
              "paint": {
                "line-color": "#FFFFFF",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.16, 13, 0.62],
                "line-opacity": 0.38
              }
            },
            {
              "id": "kecamatan-boundaries",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "kecamatan",
              "paint": {
                "line-color": "#D4D4D4",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.32, 13, 0.92],
                "line-opacity": 0.42
              }
            },
            {
              "id": "roads-casing",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "roads",
              "paint": {
                "line-color": "#D6D6D6",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.95, 13, 4.2],
                "line-opacity": 0.72
              }
            },
            {
              "id": "roads",
              "type": "line",
              "source": "bali-basemap",
              "source-layer": "roads",
              "paint": {
                "line-color": "#FFFFFF",
                "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 13, 2.85],
                "line-opacity": 1.0
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
