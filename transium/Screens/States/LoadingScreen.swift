//
//  LoadingScreen.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI

struct LoadingScreen: View {
    
    var size: CGFloat = 210
    /// Stroke thickness.
    var lineWidth: CGFloat = 15
    /// Ring color.
    var color: Color = .white

    @State private var isRotating = false

    
    var body: some View {
        ZStack {
            ZStack {
                TransiumColor.primaryBlue
                
                LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(0.0), location: 0.0),
                                    .init(color: .white.opacity(0.18), location: 0.45),
                                    .init(color: .white.opacity(0.0), location: 0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
            }
            .ignoresSafeArea()
            
            
            
            Circle()
                       // Trim leaves a gap so it reads as an open ring rather than a full circle.
                .trim(from: 0.1, to: 0.9)
                       .stroke(
                           AngularGradient(
                               // Stop locations are fractions of the FULL circle (0...1),
                               // even though we only draw 78% of it via .trim above.
                               // Placing the full-opacity stop at 0.78 makes the solid
                               // "head" land exactly at the tip of the trimmed arc,
                               // instead of appearing partway through as a bright dot.
                               gradient: Gradient(stops: [
                                   .init(color: color.opacity(0.0), location: 0.0),
                                   .init(color: color.opacity(0.4), location: 0.45),
                                   .init(color: color, location: 0.78)
                               ]),
                               center: .center
                           ),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                       )
                       .frame(width: size, height: size)
                       .rotationEffect(.degrees(isRotating ? 360 : 0))
                       .animation(
                           .linear(duration: 1.1).repeatForever(autoreverses: false),
                           value: isRotating
                       )
                       .onAppear { isRotating = true }

        }
    }
}

#Preview {
    LoadingScreen()
}

   
 
