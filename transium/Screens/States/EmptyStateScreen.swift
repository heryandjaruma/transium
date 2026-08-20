//
//  EmptyStateScreen.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI

struct EmptyStateScreen: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ZStack {
                GeometryReader { geo in
                           ZStack {
                               Path { path in
                                   path.move(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                   path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                                   path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                                   path.closeSubpath()
                               }
                               .fill(TransiumColor.primaryBlue)
                               
                               Path { path in
                                   path.move(to: CGPoint(x: 0, y: 0))
                                   path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                                   path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                                   path.closeSubpath()
                               }
                               .fill(TransiumColor.primaryBlue.opacity(0.95))
                           }
                       }
                       .background(Color.white) // required: opacity above blends against this
                       .ignoresSafeArea()
            }
            
            VStack {
                
                Image("Hammer")
                    .resizable()
                    .frame(width: 90, height: 90)
                
                Text("Whoops, Sorry!")
                    .font(TransiumFont.display(36))
                    .foregroundStyle(.white)
                
                VStack {
                    Text("This page is still in progress.")
                    Text("Check out our available page.")
                }
                .font(TransiumFont.body(17))
                .foregroundStyle(.white)
                
                TransiumPrimaryButton(
                    title: "Go back to Home 􀄫") {
                        dismiss()
                    }
                    .padding()
                    .accessibilityLabel("Go back to Home")
            }
        }
    }
}

#Preview {
    EmptyStateScreen()
}
