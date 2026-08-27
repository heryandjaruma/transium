//
//  SummaryIntroView.swift
//  transium
//

import SwiftUI
import UIKit

struct SummaryIntroView: View {
    let cards: [StatCardData]
    var locationLabel: String = "Sanur Street"
    var calorieMessage: String = "This trip burned 250 calories. That's like doing 1,000 jumping jacks 🥵"
    var badgeImageUrl: String? = nil

    @State private var animatedIn: Bool = false
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                ZStack {
                    // Background Ambient Rays & Stars
                    VStack {
                        ZStack {
                            Image("ShortcutSementara")
                                .resizable()
                                .frame(width: 400, height: 500)
                                .opacity(animatedIn ? 1.0 : 0.0)
                                .scaleEffect(animatedIn ? 1.0 : 0.85)
                                .animation(.easeOut(duration: 0.6), value: animatedIn)
                            
                            Image("2-Stars")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .offset(x: -120, y: -55)
                                .opacity(animatedIn ? 1.0 : 0.0)
                                .scaleEffect(animatedIn ? 1.0 : 0.4)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animatedIn)
                            
                            Image("2-Stars")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .offset(x: -120, y: 130)
                                .scaleEffect(x: -1, y: 1)
                                .opacity(animatedIn ? 1.0 : 0.0)
                                .scaleEffect(animatedIn ? 1.0 : 0.4)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.28), value: animatedIn)
                        }
                        
                        Spacer()
                    }
                
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // Hero Postage Stamp
                        BadgeArtworkStamp(
                            badgeImageUrl: badgeImageUrl,
                            size: 195,
                            tilt: .degrees(-7.5)
                        )
                        .offset(y: 5)
                        .padding(.bottom, 4)
                        .scaleEffect(animatedIn ? 1.0 : 0.6)
                        .offset(y: animatedIn ? 0 : -35)
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.05), value: animatedIn)

                        // Location Pill
                        HStack(spacing: 6) {
                            Image("WhitePoint")
                                .resizable()
                                .frame(width: 10, height: 13)

                            Text(locationLabel)
                                .font(TransiumFont.body(12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                        .scaleEffect(animatedIn ? 1.0 : 0.8)
                        .offset(y: animatedIn ? 0 : 15)
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.78).delay(0.18), value: animatedIn)
 
                        // Staggered Stats Grid (2x2)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                SummaryBox(data: card)
                                    .scaleEffect(animatedIn ? 1.0 : 0.85)
                                    .offset(y: animatedIn ? 0 : 25)
                                    .opacity(animatedIn ? 1.0 : 0.0)
                                    .animation(
                                        .spring(response: 0.48, dampingFraction: 0.75)
                                            .delay(0.24 + Double(index) * 0.08),
                                        value: animatedIn
                                    )
                            }
                        }
                        
                        // Calorie Box
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Such a Great Trip! ✨")
                                .font(TransiumFont.display(22, weight: .bold))
                            
                            HStack(spacing: 12) {
                                Image("SummaryLamp")
                                    .resizable()
                                    .frame(width: 55, height: 55)
                                
                                Text(calorieMessage)
                                    .font(TransiumFont.body(13, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .foregroundStyle(.white)
                        .background(TransiumColor.darkBlue.opacity(0.50))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .offset(y: animatedIn ? 0 : 30)
                        .opacity(animatedIn ? 1.0 : 0.0)
                        .animation(.spring(response: 0.52, dampingFraction: 0.80).delay(0.56), value: animatedIn)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            animatedIn = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// Backward-compatibility aliases
typealias Summary = SummaryIntroView
typealias JourneySummaryIntroView = SummaryIntroView

#Preview {
    SummaryIntroView(cards: [
        StatCardData(title: "Distance", value: "17", unit: "km", icon: "distance-icon"),
        StatCardData(title: "Cost Saved", value: "4.4k", unit: "Rp", icon: "cost-icon"),
        StatCardData(title: "Calories", value: "2500", unit: nil, icon: "calorie-icon"),
        StatCardData(title: "Total Steps", value: "3600", unit: nil, icon: "steps-icon")
    ])
}
