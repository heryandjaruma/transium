//
//  SummaryScreen-2.swift
//  transium
//
//  Created by Beatrice Deviana on 19/08/26.
//

import SwiftUI

struct SummaryScreen_2: View {
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
                
                TransiumPrimaryButton(
                    title: "􀈂 Share your experience") {
                    }
                    .padding()
                    .accessibilityLabel("Go to the Next Trip ")
                
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
    SummaryScreen_2()
}
