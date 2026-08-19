//
//  SettingsScreen.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLanguage: Language = .indonesia
    @State private var voiceVolume: Double = 0.6
    @State private var musicVolume: Double = 0.5
    @State private var isPermissionExpanded: Bool = false

    @State private var newQuestAnnouncement: Bool = true
    @State private var promotionalNotifications: Bool = true
    @State private var healthAndFitness: Bool = true

    enum Language {
        case indonesia, english
    }

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    languageCard
                    voiceCard
                    musicCard
                    permissionCard

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            Text("Settings")
                .font(TransiumFont.display(24, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(TransiumColor.primaryBlue)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Language Card
    private var languageCard: some View {
        SettingsCard {
            SettingsSectionLabel(icon: "translate", title: "Language")

            HStack(spacing: 8) {
                LanguageOptionButton(
                    flag: "🇮🇩",
                    title: "Indonesia",
                    isSelected: selectedLanguage == .indonesia
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLanguage = .indonesia
                    }
                }

                LanguageOptionButton(
                    flag: "🇺🇸",
                    title: "English",
                    isSelected: selectedLanguage == .english
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLanguage = .english
                    }
                }
            }
        }
    }

    // MARK: - Voice Card
    private var voiceCard: some View {
        SettingsCard {
            SettingsSectionLabel(icon: "speaker.wave.2.fill", title: "Voice")
            VolumeSlider(value: $voiceVolume)
        }
    }

    // MARK: - Music Card
    private var musicCard: some View {
        SettingsCard {
            SettingsSectionLabel(icon: "music.note", title: "Music")
            VolumeSlider(value: $musicVolume)
        }
    }

    // MARK: - Permission Card
    private var permissionCard: some View {
        SettingsCard {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPermissionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permission")
                            .font(TransiumFont.body(17, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Manage app permissions")
                            .font(TransiumFont.body(13))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isPermissionExpanded ? 180 : 0))
                }
            }

            if isPermissionExpanded {
                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "questionmark.circle.fill",
                        title: "New Quest Announcement",
                        subtitle: "Get trip updates, reminders, and important alerts.",
                        isOn: $newQuestAnnouncement
                    )

                    PermissionRow(
                        icon: "bell.fill",
                        title: "Promotional Notifications",
                        subtitle: "Get trip updates, reminders, and important alerts.",
                        isOn: $promotionalNotifications
                    )

                    PermissionRow(
                        icon: "heart.fill",
                        title: "Health & Fitness",
                        subtitle: "Track your steps and activity during your journey.",
                        isOn: $healthAndFitness
                    )
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Screen-Specific Components

private struct LanguageOptionButton: View {
    let flag: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(flag)
                Text(title)
                    .font(TransiumFont.body(16, weight: .medium))
                    .foregroundColor(isSelected ? TransiumColor.primaryBlue : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.white.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

private struct VolumeSlider: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $value, in: 0...1)
                .tint(.white)

            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.white)
                .font(.system(size: 17))
        }
    }
}

#Preview {
    SettingsScreen()
}
