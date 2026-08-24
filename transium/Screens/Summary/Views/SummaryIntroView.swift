//
//  SummaryIntroView.swift
//  transium
//

import SwiftUI

struct SummaryIntroView: View {
    let cards: [StatCardData]
    var locationLabel: String = "Sanur Street"
    var calorieMessage: String = "This trip burned 250 calories. That's like doing 1,000 jumping jacks 🥵"
    var badgeImageUrl: String? = nil
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                ZStack {
                    VStack {
                        ZStack {
                            Image("ShortcutSementara")
                                .resizable()
                                .frame(width: 400, height: 500)
                            
                            Image("2-Stars")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .offset(x: -120, y: -55)
                            
                            Image("2-Stars")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .offset(x: -120, y: 130)
                                .scaleEffect(x: -1, y: 1)
                        }
                        
                        Spacer()
                    }
                
                    VStack(spacing: 12) {
                        Spacer()
                        
                        TransiumStampCard(
                            size: 165,
                            tilt: .degrees(-4),
                            variant: .classic
                        ) {
                            BadgeArtworkImage(urlString: badgeImageUrl)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                        .padding(.bottom, 4)

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
 
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(cards) { SummaryBox(data: $0) }
                        }
                        
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
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
