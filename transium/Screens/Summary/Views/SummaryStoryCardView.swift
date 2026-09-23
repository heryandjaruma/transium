//
//  SummaryStoryCardView.swift
//  transium
//

import SwiftUI

/// A vertical 9:16 story card designed for sharing to Instagram Stories, WhatsApp, and social media.
struct SummaryStoryCardView: View {
    let cards: [StatCardData]
    let origin: String
    let destination: String
    let tripTitle: String
    let calorieMessage: String
    var badgeImage: UIImage? = nil
    var mapImage: UIImage? = nil
    var badgeImageUrl: String? = nil
    var journey: JourneyResult? = nil
    var path: [JourneyPathPoint] = []

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            // Authentic Transium Primary Blue Background
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Branding (safe below Instagram Story top bar)
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)

                        Text("TRANSIUM")
                            .font(TransiumFont.display(18, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(2)
                    }

                    Spacer()

                    Text("TRIP SUMMARY")
                        .font(TransiumFont.body(10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.20))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 51)

                Spacer(minLength: 6)

                // Hero Postage Stamp Badge with Coaxial Sunburst Rays
                ZStack {
                    // Sunburst rays radiating directly behind the badge (isolated background)
                    Image("BadgeShine")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 380, height: 380)
                        .opacity(0.85)

                    Image("Confetti-L")
                        .resizable()
                        .frame(width: 52, height: 90)
                        .offset(x: -110, y: -35)

                    Image("Confetti-R")
                        .resizable()
                        .frame(width: 52, height: 90)
                        .offset(x: 115, y: -16)

                    TransiumStampCard(size: 160, tilt: .degrees(0), variant: .classic) {
                        if let badgeImage {
                            Image(uiImage: badgeImage)
                                .resizable()
                                .scaledToFill()
                        } else if let localName = badgeImageUrl, let local = UIImage(named: localName) {
                            Image(uiImage: local)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color(red: 0.95, green: 0.60, blue: 0.20).opacity(0.15)
                                Image(systemName: "rosette")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(24)
                                    .foregroundColor(TransiumColor.primaryBlue.opacity(0.85))
                            }
                        }
                    }
                    .rotationEffect(.degrees(-7.5))
                    .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
                }
                .frame(height: 165)
                .padding(.bottom, 4)

                // Outlined Title & Splash Starburst
                ZStack {
                    OutlinedText(
                        text: tripTitle,
                        font: TransiumFont.display(36, weight: .bold),
                        fillColor: .white,
                        strokeColor: TransiumColor.primaryBlue,
                        strokeWidth: 4.5
                    )
                    .rotationEffect(.degrees(-5))
                    .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 3)

                    Image("Splash")
                        .resizable()
                        .frame(width: 46, height: 40)
                        .offset(x: 82, y: -22)
                }
                .padding(.top, -6)
                .padding(.bottom, 6)

                // Main White Story Card Container
                VStack(spacing: 10) {
                    // Origin -> Destination
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image("RedPoint")
                                .resizable()
                                .frame(width: 11, height: 11)
                            Text(origin)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black.opacity(0.6))

                        HStack(spacing: 4) {
                            Image("GreenPoint")
                                .resizable()
                                .frame(width: 11, height: 11)
                            Text(destination)
                        }
                    }
                    .font(TransiumFont.body(12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.top, 12)

                    // MapLibre Vector Map Preview
                    Group {
                        if let mapImage {
                            Image(uiImage: mapImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 155)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            SummaryMapView(journey: journey, path: path)
                                .frame(height: 155)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.horizontal, 12)

                    // 4 Stats Grid (2x2)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(cards) { card in
                            SummaryBox(data: card)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 5)

                Spacer(minLength: 6)

                // Footer Callout (safe above Instagram's bottom text entry bar)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)

                    Text("Transited sustainably with Transium")
                        .font(TransiumFont.body(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.bottom, 38)
            }
        }
        .frame(width: 414, height: 896)
    }
}

// Backward-compatibility aliases
typealias SummaryStoryCard = SummaryStoryCardView

#Preview("Story Card 9:16") {
    SummaryStoryCardView(
        cards: [
            StatCardData(title: "Distance", value: "41", unit: "km", icon: "distance-icon"),
            StatCardData(title: "Cost Saved", value: "25k", unit: "Rp", icon: "cost-icon"),
            StatCardData(title: "Calories", value: "2028", unit: nil, icon: "calorie-icon"),
            StatCardData(title: "Total Steps", value: "54068", unit: nil, icon: "steps-icon")
        ],
        origin: "RS Murni Teguh",
        destination: "Sentral Parkir Monkey Forest",
        tripTitle: "PrimaTrip",
        calorieMessage: "Great job taking transit!",
        badgeImageUrl: nil
    )
}
