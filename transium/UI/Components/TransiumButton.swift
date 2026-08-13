//
//  TransiumButton.swift
//  transium
//

import SwiftUI

struct TransiumPrimaryButton: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let shadowColor: Color?
    let action: () -> Void

    init(
        title: String,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        shadowColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shadowColor = shadowColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TransiumFont.body(18, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(buttonSurface)
                .compositingGroup()
                .clipShape(.capsule)
                .shadow(color: resolvedShadowColor, radius: 0, y: 5)
        }
        .buttonStyle(.transiumNoOpacity)
        .accessibilityAddTraits(.isButton)
    }

    private var buttonSurface: some View {
        Capsule()
            .fill(backgroundColor)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: 18)
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
            }
    }

    private var resolvedShadowColor: Color {
        shadowColor ?? backgroundColor.transiumDarkerShadow
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
        .buttonStyle(.transiumNoOpacity)
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
        .buttonStyle(.transiumNoOpacity)
    }
}

private struct TransiumNoOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
    }
}

private extension ButtonStyle where Self == TransiumNoOpacityButtonStyle {
    static var transiumNoOpacity: TransiumNoOpacityButtonStyle {
        TransiumNoOpacityButtonStyle()
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
            TransiumPrimaryButton(
                title: "Start",
                backgroundColor: TransiumColor.primaryYellow,
                foregroundColor: .black
            ) {}
        }
        .padding()
    }
}

private extension Color {
    var transiumDarkerShadow: Color {
        if self == .white {
            return Color(red: 0.82, green: 0.82, blue: 0.78)
        }

        if self == .black {
            return Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.42)
        }

        if self == TransiumColor.primaryYellow {
            return Color(red: 0.78, green: 0.52, blue: 0.08)
        }

        if self == TransiumColor.primaryBlue {
            return Color(red: 0.12, green: 0.28, blue: 0.64)
        }

        return Color.black.opacity(0.22)
    }
}
