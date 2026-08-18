//
//  EmptyStateScreen.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI

struct EmptyStateScreen: View {
    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()
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
                    title: "Go back to Home 􀄫") {}
                    .padding()
            }
        }
        
//        TransiumCapsuleTextButton(title: "Go back to Home", action: HomeScreen())
//            .accessibilityLabel("Go back to Home")
    }
}

#Preview {
    EmptyStateScreen()
}
