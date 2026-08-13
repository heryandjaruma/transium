//
//  TransiumButton.swift
//  transium
//

import SwiftUI

struct TransiumPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TransiumFont.body(16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white)
                .clipShape(.capsule)
                .shadow(color: .black.opacity(0.18), radius: 0, y: 4)
        }
        .accessibilityAddTraits(.isButton)
    }
}

struct TransiumIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(.white)
                .clipShape(.circle)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct TransiumCapsuleTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TransiumFont.body(17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.12))
                .clipShape(.capsule)
        }
    }
}

#Preview {
    ZStack {
        TransiumColor.primaryBlue
            .ignoresSafeArea()

        VStack(spacing: 24) {
            TransiumIconButton(systemName: "arrow.left", accessibilityLabel: "Back") {}
            TransiumCapsuleTextButton(title: "Skip") {}
            TransiumPrimaryButton(title: "Next") {}
        }
        .padding()
    }
}
