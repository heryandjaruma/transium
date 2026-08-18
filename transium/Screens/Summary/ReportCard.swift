//
//  ReportCard.swift
//  transium
//
//  Created by Beatrice Deviana on 19/08/26.
//

import SwiftUI

struct ReportCard: View {
    
    let cards: [StatCardData]
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()
            
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
            
        }
    }
}

#Preview {
    ReportCard(cards: [
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
