//
//  SummaryScreen-2.swift
//  transium
//
//  Created by Beatrice Deviana on 19/08/26.
//

import SwiftUI

struct SummaryCelebrationScreen: View {

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
            ZStack{
                VStack {
                    Image("BadgeShine")
                        .resizable()
                        .frame(width: 400, height: 400)
                    Spacer()
                }
                .offset(y:-110)

            }
            
            VStack {
                ZStack{
                    ZStack {
                        
                        Image("Confetti-L")
                            .resizable()
                            .frame(width: 63, height: 108)
                            .offset(x: -110, y: -50)
                        
                        Image("Confetti-R")
                            .resizable()
                            .frame(width: 63, height: 108)
                            .offset(x: 130, y: -20)
                        
                    }
                    ZStack{

                        BadgeArtworkImage(urlString: badgeImageUrl)
                            .frame(width: 150, height: 150)

                    }
                }

                ZStack(alignment: .top){

                    VStack {
                        HStack {
                            Image("RedPoint")
                                .resizable()
                                .frame(width: 12, height: 12)
                            
                            Text(origin)

                            Image(systemName: "arrow.right")

                            Image("GreenPoint")
                                .resizable()
                                .frame(width: 12, height: 12)

                            Text(destination)
                            
                        }
                        .padding(.top, 20)
                        .font(TransiumFont.body(13).weight(.semibold))
                        
                        Image("map")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
                        Divider()
                        
                        LazyVGrid(columns: columns) {
                            ForEach(cards) { SummaryBox(data: $0) }
                        }
                        
                    }
                    .foregroundStyle(.black)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    
                    ZStack{
                        OutlinedText(
                            text: tripTitle,
                            font: TransiumFont.display(43),
                            fillColor: .white,
                            strokeColor: .primaryBlue,
                            strokeWidth: 5
                        )
                        .rotationEffect(.degrees(-5))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 5)
                        
                        Image("Splash")
                            .resizable()
                            .frame(width: 58, height: 52)
                            .offset(x: 100, y: -30)
                    }
                    .offset(y: -20)

                }
                

                VStack(spacing: 15) {
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
                        foregroundColor: .blue,
                        icon: "arrow.right",
                        iconPosition: .trailing,
                        action: onNext
                    )
                    .accessibilityLabel("Go to the Next Trip")
                }
                .padding(.horizontal)
            }
            

        }
        
    }
}

#Preview {
    SummaryCelebrationScreen(cards: [
        StatCardData(title: "Distance", value: "17", unit: "km",
                     icon: "distance-icon"),
        StatCardData(title: "Travel Cost", value: "4.4k", unit: "Rp",
                     icon: "cost-icon"),
        StatCardData(title: "Calories", value: "2500", unit: nil,
                     icon: "calorie-icon"),
        StatCardData(title: "Total Steps", value: "3600", unit: nil,
                     icon: "steps-icon")
    ])
}
