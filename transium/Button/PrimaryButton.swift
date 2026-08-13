//
//  PrimaryButton.swift
//  transium
//
//  Created by Awfar on 12/08/26.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(
                    color: .black.opacity(0.18),
                    radius: 0,
                    y: 4
                )
        }
    }
}

#Preview {
    ZStack {
        Color("PrimaryBlue")
            .ignoresSafeArea()

        PrimaryButton(title: "Next") {
            print("Next tapped")
        }
        .padding(.horizontal, 20)
    }
}
