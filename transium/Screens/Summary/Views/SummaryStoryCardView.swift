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
    let badgeImageUrl: String?
    var journey: JourneyResult? = nil
    var path: [JourneyPathPoint] = []

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            // Instagram Story Gradient Background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.44, blue: 0.88),
                    Color(red: 0.04, green: 0.28, blue: 0.65),
                    Color(red: 0.02, green: 0.16, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Top Header Branding
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text("TRANSIUM")
                            .font(TransiumFont.display(20, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(2)
                    }

                    Spacer()

                    Text("TRIP SUMMARY")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)

                Spacer(minLength: 4)

                // Hero Postage Stamp Badge with Tilt
                ZStack {
                    Image("Confetti-L")
                        .resizable()
                        .frame(width: 54, height: 92)
                        .offset(x: -110, y: -30)

                    Image("Confetti-R")
                        .resizable()
                        .frame(width: 54, height: 92)
                        .offset(x: 120, y: -10)

                    BadgeArtworkStamp(
                        badgeImageUrl: badgeImageUrl,
                        size: 165,
                        tilt: .degrees(-7.5)
                    )
                }

                // Title & Splash Starburst
                ZStack {
                    OutlinedText(
                        text: tripTitle,
                        font: TransiumFont.display(38, weight: .bold),
                        fillColor: .white,
                        strokeColor: TransiumColor.primaryBlue,
                        strokeWidth: 4.5
                    )
                    .rotationEffect(.degrees(-4))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)

                    Image("Splash")
                        .resizable()
                        .frame(width: 44, height: 38)
                        .offset(x: 88, y: -20)
                }
                .padding(.top, -6)

                // White Story Card Container
                VStack(spacing: 12) {
                    // Origin -> Destination
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image("RedPoint")
                                .resizable()
                                .frame(width: 11, height: 11)
                            Text(origin)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))

                        HStack(spacing: 4) {
                            Image("GreenPoint")
                                .resizable()
                                .frame(width: 11, height: 11)
                            Text(destination)
                        }
                    }
                    .font(TransiumFont.body(12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.top, 14)

                    // Vector Map Preview
                    SummaryMapView(journey: journey, path: path)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 14)

                    Divider()
                        .padding(.horizontal, 14)

                    // 4 Stats Grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(cards) { card in
                            SummaryBox(data: card)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)

                Spacer(minLength: 8)

                // Footer Callout
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)

                    Text("Transited sustainably with Transium")
                        .font(TransiumFont.body(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.90))
                }
                .padding(.bottom, 36)
            }
        }
        .frame(width: 390, height: 844)
    }
}
