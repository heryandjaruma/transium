//
//  HomeScreen.swift
//  transium
//

import CoreLocation
import MapLibre
import SwiftUI

struct HomeScreen: View {
    @StateObject private var locationStore = LocationStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            LocalBaliMapView(currentLocation: locationStore.currentLocation)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                mapBadge
                locationCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .task {
            locationStore.requestCurrentLocation()
        }
        .preferredColorScheme(.light)
    }

    private var mapBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bali Transit")
                .font(TransiumFont.display(26))
                .foregroundStyle(.primary)

            Text("Local PMTiles map")
                .font(TransiumFont.body(12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.82))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bali Transit local PMTiles map")
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: locationIconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)

                Text(locationTitle)
                    .font(TransiumFont.body(12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(locationSubtitle)
                .font(TransiumFont.body(11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button(action: locationStore.requestCurrentLocation) {
                Text("Center my location")
                    .font(TransiumFont.body(11, weight: .semibold))
                    .foregroundStyle(TransiumColor.linkBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.82))
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        .frame(maxWidth: 230, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var locationIconName: String {
        locationStore.currentLocation == nil ? "location" : "location.fill"
    }

    private var locationTitle: String {
        locationStore.currentLocation == nil ? "Finding your location" : "You are here"
    }

    private var locationSubtitle: String {
        guard let coordinate = locationStore.currentLocation?.coordinate else {
            return "Allow location access to show your position on the Bali map."
        }

        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}

private struct LocalBaliMapView: UIViewRepresentable {
    let currentLocation: CLLocation?

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.compassViewPosition = .topRight
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.contentInset = UIEdgeInsets(top: 90, left: 0, bottom: 0, right: 0)
        mapView.setCenter(
            CLLocationCoordinate2D(latitude: -8.4095, longitude: 115.1889),
            zoomLevel: 9.35,
            animated: false
        )

        do {
            mapView.styleURL = try TransiumMapStyleFactory.makeLocalBaliStyleURL()
        } catch {
            AppToastCenter.shared.showError(
                title: "Map could not load",
                message: "The local Bali map files are missing or unavailable."
            )
        }

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        guard let currentLocation else {
            return
        }

        mapView.setCenter(
            currentLocation.coordinate,
            zoomLevel: max(mapView.zoomLevel, 12.8),
            animated: true
        )
    }
}

#Preview {
    HomeScreen()
}
