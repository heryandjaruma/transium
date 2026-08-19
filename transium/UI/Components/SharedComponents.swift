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

// MARK: - Quest Row

struct QuestRow: View {
    let quest: DetailPlaceScreen.Quest

    var body: some View {
        HStack(spacing: 14) {
            Image(quest.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(TransiumFont.body(14, weight: .semibold))
                    .foregroundColor(.black)

                Text(quest.description)
                    .font(TransiumFont.body(11, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .center, spacing: 6) {
                Button {
                    // start quest action
                } label: {
                    Text("Start Quest")
                        .font(TransiumFont.body(11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(quest.theme.accent)
                        .clipShape(Capsule())
                }

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("+\(quest.points) pts")
                        .font(TransiumFont.body(11, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .background(quest.theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Recommended Quest Card
struct RecommendedQuestCard: View {
    var body: some View {
        let accent = Color(red: 0.20, green: 0.42, blue: 0.95)
 
        // HStack (bukan ZStack) supaya blok teks ada di kiri
        // dan blok gambar+tombol otomatis terdorong ke kanan card.
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECOMMENDED")
                    .font(TransiumFont.body(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
 
                Text("Early Bird Walk")
                    .font(TransiumFont.body(19, weight: .bold))
                    .foregroundColor(.white)
 
                Text("Visit Sanur before 8 AM and capture the sunrise.")
                    .font(TransiumFont.body(13))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
 
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    Text("+10 pts")
                        .font(TransiumFont.body(12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TransiumColor.darkBlue.opacity(0.9))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading) // ambil semua ruang tersisa di kiri
 
            // Kolom kanan: foto (Wow + sanoored), tombol Start Quest menumpuk di bawahnya.
            ZStack(alignment: .bottom) {
                ZStack(alignment: .center) {
                    Image("Wow")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 120)
                    Image("sanoored")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
 
                TransiumPrimaryButton(
                    title: "Start Quest",
                    backgroundColor: .white,
                    foregroundColor: accent,
                    trailingIcon: "arrow.right",
                    height: 36,
                    fillWidth: false,
                    font: TransiumFont.body(15, weight: .semibold),
                    iconHorizontalPadding: 10
                ) {
                    // start quest action
                }
            }
            .frame(width: 120)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [accent, accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        RecommendedQuestCard()
            .padding(20)
    }
}

#Preview {
    PaymentMethod()
}

#Preview {
    Permission()
}

