//
//  HomePinningOverlayView.swift
//  transium
//

import CoreLocation
import SwiftUI

struct HomePinningOverlayControls: View {
    var onBack: () -> Void
    var onLocate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }

                Spacer()

                Button(action: onLocate) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Drag the point anywhere on the map.")
                    .font(TransiumFont.body(13, weight: .semibold))
            }
            .foregroundColor(TransiumColor.primaryBlue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)

            Spacer()
        }
        .padding(.top, 6)
        .transition(.opacity)
    }
}

struct HomeCenterPinIndicator: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("location_red")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 14, height: 4)
                .offset(y: -4)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
