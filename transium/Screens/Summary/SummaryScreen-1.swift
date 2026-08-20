//
//  SummaryScreen.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI

struct SummaryScreen_1: View {
    
    let cards: [StatCardData]
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
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
                                .offset(x: -120
                                        , y: -55)
                            
                            Image("2-Stars")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .offset(x: -120
                                        , y: 130)
                                .scaleEffect(x: -1, y: 1)
                        }
                        
                        
                        
                        Spacer()
                    }
                
                    VStack (spacing: 10){
                        Spacer()
                        
                        Image("SampleBadge")
                            .resizable()
                            .frame(width: 200, height: 200)
                        
                        HStack{
                            Image("WhitePoint")
                                .resizable()
                                .frame(width: 10, height: 13)
                            
                            Text("Sanur Street")
                                .font(TransiumFont.body(12).bold())
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .offset(x: 0
                                , y: -10)
 
                        LazyVGrid(columns: columns) {
                            ForEach(cards) { SummaryBox(data: $0) }
                        }
                        

                        VStack (alignment: .leading){
                            Text("Cool! ✨") //\(random texts?)
                                .font(TransiumFont.display(21))
                            
                            HStack {
                                Image("SummaryLamp")
                                    .resizable()
                                    .frame(width: 65, height: 65)
                                
                                Text("This trip burned 250 calories. That’s like doing 1,000 jumping jacks 🥵")
                                    .font(TransiumFont.body(14))
                            }
                            
                        }
                        .padding()
                        .foregroundStyle(.white)
                        .background(Color.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .padding()
                    
                    
                }
            }
            
        }
            
    }
}

#Preview {
    SummaryScreen_1(cards: [
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


