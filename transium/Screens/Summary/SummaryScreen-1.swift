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
                        Image("ShortcutSementara")
                            .resizable()
                            .frame(width: 400, height: 500)
                        
                        Spacer()
                    }
                
                    VStack (spacing: 20){
                        Spacer()
                        
                        Image("SampleBadge")
                            .resizable()
                            .frame(width: 200, height: 200)
                        
                       
                        
                        LazyVGrid(columns: columns) {
                            ForEach(cards) { SummaryBox(data: $0) }
                        }
                        
                     
                        
                        VStack (alignment: .leading){
                            Text("Cool! ✨")
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
                    
                    
                }
            }
            
        }
            
    }
}

#Preview {
    SummaryScreen_1(cards: [
        StatCardData(title: "Total Distance", value: "17", unit: "km",
                     icon: "distance-icon"),
        StatCardData(title: "Cost Total", value: "4.4k", unit: "Rp",
                     icon: "cost-icon"),
        StatCardData(title: "Calorie Burn", value: "2500", unit: nil,
                     icon: "calorie-icon"),
        StatCardData(title: "Total Steps", value: "3600", unit: nil,
                     icon: "steps-icon")
    ])
}


