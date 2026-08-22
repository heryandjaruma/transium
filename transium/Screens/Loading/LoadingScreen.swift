//
//  LoadingScreen.swift
//  transium
//

import SwiftUI

struct LoadingScreen: View {
    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            TransiumLoadingSpinner(size: 180, lineWidth: 4.5, busSize: 104)
        }
    }
}

// MARK: - Reusable Smooth Eased Loading Spinner

struct TransiumLoadingSpinner: View {
    var size: CGFloat = 180
    var lineWidth: CGFloat = 4.5
    var busSize: CGFloat = 104

    @State private var isSpinning: Bool = false
    @State private var isPulsing: Bool = false
    @State private var trimStart: CGFloat = 0.05
    @State private var trimEnd: CGFloat = 0.72

    var body: some View {
        ZStack {
            // Subtle track background
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Smooth eased dynamic arc
            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .shadow(color: Color.white.opacity(0.4), radius: 8)

            // Centered Bus icon with breathing animation
            Image("bus_new")
                .resizable()
                .scaledToFit()
                .frame(width: busSize, height: busSize)
                .scaleEffect(isPulsing ? 1.03 : 0.97)
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
        }
        .onAppear {
            // Eased rotation
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                isSpinning = true
            }

            // Elastic arc trim breathing
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                trimStart = 0.2
                trimEnd = 0.85
            }

            // Subtle bus pulse
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    LoadingScreen()
}
