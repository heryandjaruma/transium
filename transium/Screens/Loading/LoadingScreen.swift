//
//  LoadingScreen.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI

struct LoadingScreen: View {
    @State private var isRotating = false

    var body: some View {
        ZStack {
            // Background
            Color("PrimaryBlue")
                .ignoresSafeArea()

            // Spinner + Bus Icon
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.2)
                        .repeatForever(autoreverses: false),
                        value: isRotating
                    )

                Image("Bus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            }
        }
        .onAppear {
            isRotating = true
        }
    }
}

#Preview {
    LoadingScreen()
}
