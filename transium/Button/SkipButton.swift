//
//  SkipButton.swift
//  transium
//
//  Created by Awfar on 12/08/26.
//

import SwiftUI

struct SkipButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text("Skip")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    ZStack {
        Color("PrimaryBlue")
            .ignoresSafeArea()

        SkipButton {
            print("Skip tapped")
        }
    }
}
