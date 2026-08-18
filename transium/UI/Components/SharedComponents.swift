//
//  SharedComponents.swift
//  transium
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .background(TransiumColor.darkBlue)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct SettingsSectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 21))
            Text(title)
                .font(TransiumFont.body(17, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var backgroundColor: Color = .white
    var shadowColor: Color? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 30))
                .frame(width: 47, height: 47)
                .background(TransiumColor.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TransiumFont.body(15, weight: .semibold))
                    .foregroundColor(TransiumColor.darkBlue)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(TransiumFont.body(12, weight: .medium))
                    .foregroundColor(TransiumColor.darkBlue.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(TransiumColor.primaryBlue)
                .scaleEffect(0.85)
                .frame(width: 44, height: 26)
        }
        .padding(12)
        .background(rowSurface)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: resolvedShadowColor, radius: 0, y: 5)
    }

    private var rowSurface: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.18))
                    .frame(height: 14)
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
            }
    }

    private var resolvedShadowColor: Color {
        shadowColor ?? backgroundColor.transiumDarkerShadow
    }
}

struct PaymentMethodRow: View {
    var icon: String? = nil
    var iconImage: String? = nil
    let title: String
    let subtitle: String
    var backgroundColor: Color = TransiumColor.darkBlue
    var shadowColor: Color? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TransiumFont.body(17, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(TransiumFont.body(13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(rowSurface)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconImage {
            Image(iconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .frame(width: 47, height: 47)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let icon {
            Image(systemName: icon)
                .foregroundColor(TransiumColor.darkBlue)
                .font(.system(size: 30))
                .frame(width: 47, height: 47)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var rowSurface: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor)
    }

    private var resolvedShadowColor: Color {
        shadowColor ?? backgroundColor.transiumDarkerShadow
    }
}


#Preview {
    PaymentMethod()
}

#Preview {
    Permission()
}
