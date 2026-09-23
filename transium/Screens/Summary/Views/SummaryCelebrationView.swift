//
//  SummaryCelebrationView.swift
//  transium
//

import SwiftUI
import UIKit

struct SummaryCelebrationView: View {
    let cards: [StatCardData]
    var origin: String = "Jimbaran"
    var destination: String = "Sanur Beach"
    var tripTitle: String = "Sanoored"
    var badgeImageUrl: String? = nil
    var journey: JourneyResult? = nil
    var path: [JourneyPathPoint] = []
    var onShare: () -> Void = {}
    var onNext: () -> Void = {}

    @State private var animatedIn: Bool = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()
            
            // Background shine rays
            VStack {
                Image("BadgeShine")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .rotationEffect(.degrees(animatedIn ? 0 : -30))
                    .scaleEffect(animatedIn ? 1.0 : 0.6)
                    .opacity(animatedIn ? 0.9 : 0.0)
                    .animation(.easeOut(duration: 0.7), value: animatedIn)
                Spacer()
            }
            .offset(y: -110)
            
            VStack(spacing: 0) {
                // Top Badge with Confetti & Postage Stamp
                ZStack {
                    // Left Confetti Pop
                    Image("Confetti-L")
                        .resizable()
                        .frame(width: 63, height: 108)
                        .offset(x: animatedIn ? -120 : -60, y: animatedIn ? -45 : 10)
                        .scaleEffect(animatedIn ? 1.0 : 0.2)
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.10), value: animatedIn)
                    
                    // Right Confetti Pop
                    Image("Confetti-R")
                        .resizable()
                        .frame(width: 63, height: 108)
                        .offset(x: animatedIn ? 130 : 70, y: animatedIn ? -20 : 30)
                        .scaleEffect(animatedIn ? 1.0 : 0.2)
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.12), value: animatedIn)
                    
                    // Hero Postage Stamp
                    BadgeArtworkStamp(
                        badgeImageUrl: badgeImageUrl,
                        size: 195,
                        tilt: .degrees(-7.5)
                    )
                    .scaleEffect(animatedIn ? 1.0 : 0.5)
                    .offset(y: animatedIn ? 0 : -40)
                    .opacity(animatedIn ? 1.0 : 0.0)
                    .animation(.spring(response: 0.58, dampingFraction: 0.68).delay(0.04), value: animatedIn)
                }
                .padding(.top, 15)
                .padding(.bottom, 6)

                // Main White Summary Card with Outlined Title Header
                ZStack(alignment: .top) {
                    VStack(spacing: 12) {
                        // Route Origin -> Destination
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image("RedPoint")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                Text(origin)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black.opacity(0.6))
                            
                            HStack(spacing: 4) {
                                Image("GreenPoint")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                Text(destination)
                            }
                        }
                        .padding(.top, 24)
                        .font(TransiumFont.body(13, weight: .semibold))
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .offset(y: animatedIn ? 0 : 10)
                        .animation(.easeOut(duration: 0.4).delay(0.28), value: animatedIn)
                        
                        // Dynamic Map Preview
                        SummaryMapView(journey: journey, path: path)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16)
                            .scaleEffect(animatedIn ? 1.0 : 0.92)
                            .opacity(animatedIn ? 1.0 : 0.0)
                            .animation(.spring(response: 0.52, dampingFraction: 0.80).delay(0.34), value: animatedIn)
                        
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(animatedIn ? 1.0 : 0.0)
                            .animation(.easeOut(duration: 0.3).delay(0.40), value: animatedIn)
                        
                        // Staggered Stats Grid (2x2)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                SummaryBox(data: card)
                                    .scaleEffect(animatedIn ? 1.0 : 0.86)
                                    .offset(y: animatedIn ? 0 : 20)
                                    .opacity(animatedIn ? 1.0 : 0.0)
                                    .animation(
                                        .spring(response: 0.48, dampingFraction: 0.76)
                                            .delay(0.42 + Double(index) * 0.07),
                                        value: animatedIn
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .foregroundStyle(.black)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .offset(y: animatedIn ? 0 : 60)
                    .opacity(animatedIn ? 1.0 : 0.0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.14), value: animatedIn)
                    
                    // Floating Outlined Title & Splash Starburst
                    ZStack {
                        OutlinedText(
                            text: tripTitle,
                            font: TransiumFont.display(42, weight: .bold),
                            fillColor: .white,
                            strokeColor: TransiumColor.primaryBlue,
                            strokeWidth: 5
                        )
                        .rotationEffect(.degrees(animatedIn ? -5 : -18))
                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 4)
                        
                        Image("Splash")
                            .resizable()
                            .frame(width: 54, height: 48)
                            .offset(x: 95, y: -26)
                            .scaleEffect(animatedIn ? 1.0 : 0.1)
                            .opacity(animatedIn ? 1.0 : 0.0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.58).delay(0.28), value: animatedIn)
                    }
                    .offset(y: -16)
                    .scaleEffect(animatedIn ? 1.0 : 0.4)
                    .opacity(animatedIn ? 1.0 : 0.0)
                    .animation(.spring(response: 0.52, dampingFraction: 0.65).delay(0.20), value: animatedIn)
                }
                
                Spacer(minLength: 16)

                // Bottom Actions
                VStack(spacing: 12) {
                    TransiumSecondaryButton(
                        title: "Share your experience",
                        backgroundColor: .black,
                        foregroundColor: .white,
                        icon: "square.and.arrow.up",
                        iconPosition: .trailing,
                        action: onShare
                    )

                    TransiumSecondaryButton(
                        title: "Go to the Next Trip!",
                        backgroundColor: .white,
                        foregroundColor: TransiumColor.primaryBlue,
                        icon: "arrow.right",
                        iconPosition: .trailing,
                        action: onNext
                    )
                    .accessibilityLabel("Go to the Next Trip")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .offset(y: animatedIn ? 0 : 40)
                .opacity(animatedIn ? 1.0 : 0.0)
                .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.68), value: animatedIn)
            }
        }
        .onAppear {
            animatedIn = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// Backward-compatibility aliases
typealias SummaryCelebrationScreen = SummaryCelebrationView
typealias JourneySummaryCelebrationView = SummaryCelebrationView

#Preview("Celebration Card") {
    let origin = JourneyLocationRef(lat: -8.702105, lng: 115.176189, name: "Jimbaran", stopId: nil)
    let stop = JourneyLocationRef(lat: -8.6975, lng: 115.1800, name: "Sanur Beach Stop", stopId: "stop-1")
    let dest = JourneyLocationRef(lat: -8.67368, lng: 115.26337, name: "Sanur Beach", stopId: nil)

    let mockJourney = JourneyResult(
        origin: LatLng(lat: origin.lat, lng: origin.lng),
        destination: LatLng(lat: dest.lat, lng: dest.lng),
        summary: JourneyOverviewSummary(
            distanceMeters: 5200,
            walkingDistanceMeters: 1200,
            walkingDurationSeconds: 900,
            transitDistanceMeters: 4000,
            busLegCount: 1,
            transferCount: 0
        ),
        segments: [
            JourneySegment(type: "walk", from: origin, to: stop, distanceMeters: 1200, durationSeconds: 900),
            JourneySegment(type: "bus", from: stop, to: dest, distanceMeters: 4000, durationSeconds: 900, routeId: "kib-1", routeRef: "KIB", routeName: "Trans Metro Dewata")
        ],
        steps: []
    )

    SummaryCelebrationView(
        cards: [
            StatCardData(title: "Distance", value: "17", unit: "km", icon: "distance-icon"),
            StatCardData(title: "Cost Saved", value: "4.4k", unit: "Rp", icon: "cost-icon"),
            StatCardData(title: "Calories", value: "250", unit: nil, icon: "calorie-icon"),
            StatCardData(title: "Total Steps", value: "3600", unit: nil, icon: "steps-icon")
        ],
        origin: "Jimbaran",
        destination: "Sanur Beach",
        tripTitle: "Sanoored",
        journey: mockJourney
    )
}
