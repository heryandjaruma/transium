//
//  SummaryScreen-2.swift
//  transium
//
//  Created by Beatrice Deviana on 19/08/26.
//

import SwiftUI

struct SummaryScreen_2: View {
    
    let cards: [StatCardData]
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    Image("BadgeShine")
                        .resizable()
                        .frame(width: 400, height: 400)
                    
                    VStack (spacing: -20){
                        Image("SampleBadge")
                            .resizable()
                            .frame(width: 150, height: 150)
                        
                        ZStack {
                            Text("Sanoored")
                                .font(TransiumFont.display(43))
                                .foregroundStyle(Color.white)
                                .rotationEffect(.degrees(-5))
                        }
                    }
                }
                Spacer()
                
                VStack {
                    HStack {
                        Image("RedPoint")
                            .resizable()
                            .frame(width: 12, height: 12)
                        
                        Text("Jimbaran")
                        
                        Image(systemName: "arrow.right")
                        
                        Image("GreenPoint")
                            .resizable()
                            .frame(width: 12, height: 12)
                        
                        Text("Sanur Beach")
                        
                    }
                    .padding()
                    .font(TransiumFont.body(12).weight(.semibold))
                    
                    
                    Divider()
                    
                    LazyVGrid(columns: columns) {
                        ForEach(cards) { SummaryBox(data: $0) }
                    }
                    
                }
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                
                TransiumPrimaryButton(
                    title: "􀈂 Share your experience",
                    backgroundColor: .black,
                    foregroundColor: .white
                ) {}
                .padding()
                
                TransiumPrimaryButton(
                    title: "Go to the Next Trip! 􀄫") {
                    }
                    .padding()
                    .accessibilityLabel("Go to the Next Trip ")
            }  
        }
    }
}



#Preview {
    SummaryScreen_2(cards: [
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
