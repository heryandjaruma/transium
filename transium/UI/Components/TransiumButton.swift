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
 
    var buttonSurface: some View {
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
 
    var resolvedShadowColor: Color {
        shadowColor ?? backgroundColor.transiumDarkerShadow
    }
}

enum TransiumSecondaryButtonIconPosition {
    case leading
    case trailing
}

/// Tombol sekunder — capsule flat (tanpa glossy highlight & shadow solid seperti Primary),
/// warna font & background bisa diatur bebas, ikon opsional (SF Symbol).
struct TransiumSecondaryButton: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let icon: String?
    let iconPosition: TransiumSecondaryButtonIconPosition
    let height: CGFloat
    let fillWidth: Bool
    let font: Font
    let borderColor: Color?
    let action: () -> Void

    init(
        title: String,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        icon: String? = nil,
        iconPosition: TransiumSecondaryButtonIconPosition = .leading,
        height: CGFloat = 58,
        fillWidth: Bool = true,
        font: Font = TransiumFont.body(16, weight: .semibold),
        borderColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = icon
        self.iconPosition = iconPosition
        self.height = height
        self.fillWidth = fillWidth
        self.font = font
        self.borderColor = borderColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon, iconPosition == .leading {
                    iconView(icon)
                }

                Text(title)
                    .font(font)
                    .foregroundStyle(foregroundColor)

                if let icon, iconPosition == .trailing {
                    iconView(icon)
                }
            }
            .padding(.horizontal, height * 0.45)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .frame(height: height)
            .background(backgroundColor)
            .clipShape(.capsule)
            .overlay {
                if let borderColor {
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.transiumNoOpacity)
        .accessibilityAddTraits(.isButton)
    }

    private func iconView(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: height * 0.32, weight: .semibold))
            .foregroundStyle(foregroundColor)
    }
}

#Preview {
    ZStack {
        TransiumColor.primaryBlue
            .ignoresSafeArea()

        VStack(spacing: 16) {
            // Tanpa icon
            TransiumSecondaryButton(title: "Skip") {}

            // Dengan icon di kiri
            TransiumSecondaryButton(
                title: "Share your experience",
                icon: "square.and.arrow.up"
            ) {}

            // Dengan icon di kanan
            TransiumSecondaryButton(
                title: "Go to the Next Trip!",
                icon: "arrow.right",
                iconPosition: .trailing
            ) {}

            // Warna custom + border
            TransiumSecondaryButton(
                title: "Cancel",
                backgroundColor: .black,
                foregroundColor: .white,
            ) {}

            // Warna gelap
            TransiumSecondaryButton(
                title: "Learn More",
                backgroundColor: .black.opacity(0.15),
                foregroundColor: .white,
                icon: "info.circle"
            ) {}
        }
        .padding()
    }
}

/// Sumber gambar icon untuk `TransiumIconButton` — SF Symbol atau custom asset image.
enum TransiumIconSource {
    case system(String)
    case asset(String)
}

/// Bulat, dengan glossy highlight di atas + shadow solid di bawah,
/// selaras dengan gaya `TransiumPrimaryButton`. Ukuran & warna bisa diatur.
struct TransiumIconButton: View {
    let icon: TransiumIconSource
    let label: String?
    let accessibilityLabel: String
    let backgroundColor: Color
    let foregroundColor: Color
    let shadowColor: Color?
    let size: CGFloat
    let iconSize: CGFloat?
    let font: Font?
    let action: () -> Void

    init(
        icon: TransiumIconSource,
        label: String? = nil,
        accessibilityLabel: String,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        shadowColor: Color? = nil,
        size: CGFloat = 40,
        iconSize: CGFloat? = nil,
        font: Font? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shadowColor = shadowColor
        self.size = size
        self.iconSize = iconSize
        self.font = font
        self.action = action
    }

    init(
        systemName: String,
        label: String? = nil,
        accessibilityLabel: String,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        shadowColor: Color? = nil,
        size: CGFloat = 40,
        iconSize: CGFloat? = nil,
        font: Font? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            icon: .system(systemName),
            label: label,
            accessibilityLabel: accessibilityLabel,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            shadowColor: shadowColor,
            size: size,
            iconSize: iconSize,
            font: font,
            action: action
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: size * 0.04) {
                iconView
                    .frame(width: iconSize ?? size * (label == nil ? 0.45 : 0.32),
                           height: iconSize ?? size * (label == nil ? 0.45 : 0.32))

                if let label {
                    Text(label)
                        .font(font ?? TransiumFont.body(size * 0.2, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                }
            }
            .frame(width: size, height: size)
            .background(buttonSurface)
            .compositingGroup()
            .clipShape(.circle)
            .shadow(color: resolvedShadowColor, radius: 0, y: size * 0.08)
        }
        .buttonStyle(.transiumNoOpacity)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    var buttonSurface: some View {
        Circle()
            .fill(backgroundColor)
    }

    @ViewBuilder
    var iconView: some View {
        switch icon {
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: iconSize ?? size * (label == nil ? 0.45 : 0.32), weight: .medium))
                .foregroundStyle(foregroundColor)
        case .asset(let assetImageName):
            Image(assetImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(foregroundColor)
        }
    }

    var resolvedShadowColor: Color {
        shadowColor ?? backgroundColor.transiumDarkerShadow
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
            HStack(spacing: 16) {
                TransiumIconButton(
                    icon: .system("xmark"),
                    label: "END",
                    accessibilityLabel: "End",
                    backgroundColor: TransiumColor.lightRed,
                    foregroundColor: .white,
                    size: 64
                ) {}

                TransiumIconButton(
                    icon: .system("location.fill"),
                    accessibilityLabel: "Locate me",
                    size: 56
                ) {}

                TransiumIconButton(
                    icon: .system("speaker.wave.2.fill"),
                    accessibilityLabel: "Toggle sound",
                    size: 56
                ) {}

                // Contoh pakai custom asset (bukan SF Symbol), mis. "focus"
                TransiumIconButton(
                    icon: .asset("focus"),
                    accessibilityLabel: "Recenter",
                    size: 44
                ) {}
            }

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


private let strokeWidth: CGFloat = 1.5
private var strokeOffsets: [CGSize] {
    let d = strokeWidth
    return [
        CGSize(width: -d, height: -d), CGSize(width: 0, height: -d), CGSize(width: d, height: -d),
        CGSize(width: -d, height: 0),                                 CGSize(width: d, height: 0),
        CGSize(width: -d, height: d),  CGSize(width: 0, height: d),  CGSize(width: d, height: d)
    ]
}

struct OutlinedText: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    var strokeWidth: CGFloat = 1.5

    var body: some View {
        ZStack {
            ForEach(offsets, id: \.self) { offset in
                Text(text)
                    .font(font)
                    .foregroundStyle(strokeColor)
                    .offset(x: offset.width, y: offset.height)
            }

            Text(text)
                .font(font)
                .foregroundStyle(fillColor)
        }
    }

    private var offsets: [CGSize] {
        let d = strokeWidth
        return [
            CGSize(width: -d, height: -d), CGSize(width: 0, height: -d), CGSize(width: d, height: -d),
            CGSize(width: -d, height: 0),                                 CGSize(width: d, height: 0),
            CGSize(width: -d, height: d),  CGSize(width: 0, height: d),  CGSize(width: d, height: d)
        ]
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

        if self == TransiumColor.lightRed {
            return Color(red: 0.75, green: 0.25, blue: 0.22)
        }

        return Color.black.opacity(0.22)
    }
}
