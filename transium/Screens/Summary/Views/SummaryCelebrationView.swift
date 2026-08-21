//
//  SummaryCelebrationView.swift
//  transium
//

import SwiftUI

struct SummaryCelebrationView: View {
    let cards: [StatCardData]
    var origin: String = "Jimbaran"
    var destination: String = "Sanur Beach"
    var tripTitle: String = "Sanoored"
    var badgeImageUrl: String? = nil
    var onShare: () -> Void = {}
    var onNext: () -> Void = {}

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
                Spacer()
            }
            .offset(y: -110)
            
            VStack(spacing: 0) {
                // Top Badge with Confetti & Postage Stamp
                ZStack {
                    Image("Confetti-L")
                        .resizable()
                        .frame(width: 63, height: 108)
                        .offset(x: -120, y: -45)
                    
                    Image("Confetti-R")
                        .resizable()
                        .frame(width: 63, height: 108)
                        .offset(x: 130, y: -20)
                    
                    TransiumStampCard(
                        size: 155,
                        tilt: .degrees(-4),
                        variant: .classic
                    ) {
                        BadgeArtworkImage(urlString: badgeImageUrl)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .padding(.top, 10)
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
                        
                        // Map Preview
                        Image("map")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // Stats Grid
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(cards) { SummaryBox(data: $0) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .foregroundStyle(.black)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Floating Outlined Title & Splash Starburst
                    ZStack {
                        OutlinedText(
                            text: tripTitle,
                            font: TransiumFont.display(42, weight: .bold),
                            fillColor: .white,
                            strokeColor: TransiumColor.primaryBlue,
                            strokeWidth: 5
                        )
                        .rotationEffect(.degrees(-5))
                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 4)
                        
                        Image("Splash")
                            .resizable()
                            .frame(width: 54, height: 48)
                            .offset(x: 95, y: -26)
                    }
                    .offset(y: -16)
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
            }
        }
    }
}

// Backward-compatibility aliases
typealias SummaryCelebrationScreen = SummaryCelebrationView
typealias JourneySummaryCelebrationView = SummaryCelebrationView

#Preview {
    SummaryCelebrationView(cards: [
        StatCardData(title: "Distance", value: "17", unit: "km", icon: "distance-icon"),
        StatCardData(title: "Travel Cost", value: "4.4k", unit: "Rp", icon: "cost-icon"),
        StatCardData(title: "Calories", value: "2500", unit: nil, icon: "calorie-icon"),
        StatCardData(title: "Total Steps", value: "3600", unit: nil, icon: "steps-icon")
    ])
}
