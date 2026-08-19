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
    let trailingIcon: String?
    let height: CGFloat
    let fillWidth: Bool
    let font: Font
    let iconHorizontalPadding: CGFloat?
    let action: () -> Void
 
    init(
        title: String,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        shadowColor: Color? = nil,
        trailingIcon: String? = nil,
        height: CGFloat = 60,
        fillWidth: Bool = true,
        font: Font = TransiumFont.body(18, weight: .semibold),
        iconHorizontalPadding: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shadowColor = shadowColor
        self.trailingIcon = trailingIcon
        self.height = height
        self.fillWidth = fillWidth
        self.font = font
        self.iconHorizontalPadding = iconHorizontalPadding
        self.action = action
    }
 
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(font)
                    .foregroundStyle(foregroundColor)
 
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: height * 0.2, weight: .bold))
                        .foregroundColor(backgroundColor)
                        .padding(height * 0.12)
                        .background(foregroundColor)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, trailingIcon != nil ? (iconHorizontalPadding ?? height * 0.35) : 0)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .frame(height: height)
            .background(buttonSurface)
            .compositingGroup()
            .clipShape(.capsule)
            .shadow(color: resolvedShadowColor, radius: 0, y: height * 0.08)
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
                    .frame(height: max(height * 0.3, 10))
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

struct TransiumNoOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
    }
}

extension ButtonStyle where Self == TransiumNoOpacityButtonStyle {
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

extension Color {
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
