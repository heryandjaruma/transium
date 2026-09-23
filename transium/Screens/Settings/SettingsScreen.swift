//
//  SettingsScreen.swift
//  transium
//

import SwiftUI

struct SettingsScreen: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionController.self) private var session
    @Environment(AppLanguageManager.self) private var languageManager: AppLanguageManager?

    @State private var voiceVolume: Double = 0.6
    @State private var musicVolume: Double = 0.5
    @State private var isPermissionExpanded: Bool = false

    @State private var newQuestAnnouncement: Bool = true
    @State private var promotionalNotifications: Bool = true
    @State private var healthAndFitness: Bool = true

    @State private var showLogoutConfirmation: Bool = false

    private var activeLanguage: AppLanguage {
        languageManager?.currentLanguage ?? AppLanguageManager.shared.currentLanguage
    }

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    languageCard
                    voiceCard
                    musicCard
                    permissionCard
                    logoutCard

                    appFooter

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "Sign out?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                handleLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to login again with Apple later.")
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            Text("Settings")
                .font(TransiumFont.display(32, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(TransiumColor.primaryBlue)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                }
                Spacer()
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Language Card
    private var languageCard: some View {
        SettingsCard {
            SettingsSectionLabel(icon: "character.bubble.fill", title: "Language")

            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    let isSelected = activeLanguage == language
                    Button {
                        if let languageManager {
                            languageManager.setLanguage(language)
                        } else {
                            AppLanguageManager.shared.setLanguage(language)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(language.flag)
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.displayName)
                                    .font(TransiumFont.body(15, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(.white)
                                
                                Text(language == .english ? "English (US)" : "Bahasa Indonesia (ID)")
                                    .font(TransiumFont.body(12))
                                    .foregroundColor(.white.opacity(0.65))
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Voice Card
    private var voiceCard: some View {
        SettingsCard {
            HStack {
                SettingsSectionLabel(icon: "speaker.wave.2.fill", title: "Voice")
                Spacer()
                Text("\(Int(round(voiceVolume * 100)))%")
                    .font(TransiumFont.body(13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }

            VolumeSlider(value: $voiceVolume)
        }
    }

    // MARK: - Music Card
    private var musicCard: some View {
        SettingsCard {
            HStack {
                SettingsSectionLabel(icon: "music.note", title: "Music")
                Spacer()
                Text("\(Int(round(musicVolume * 100)))%")
                    .font(TransiumFont.body(13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }

            VolumeSlider(value: $musicVolume)
        }
    }

    // MARK: - Permission Card
    private var permissionCard: some View {
        SettingsCard {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPermissionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 22))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permissions")
                            .font(TransiumFont.body(16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Manage notifications & device access")
                            .font(TransiumFont.body(12))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 14, weight: .bold))
                        .rotationEffect(.degrees(isPermissionExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isPermissionExpanded {
                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "bell.badge.fill",
                        title: "Quest Announcements",
                        subtitle: "Get live trip updates, milestone alerts, and reminders.",
                        isOn: $newQuestAnnouncement
                    )

                    PermissionRow(
                        icon: "megaphone.fill",
                        title: "Promotional Alerts",
                        subtitle: "Discover newly unlocked routes and community events.",
                        isOn: $promotionalNotifications
                    )

                    PermissionRow(
                        icon: "heart.fill",
                        title: "Health & Fitness",
                        subtitle: "Track your walking distance, calories, and steps.",
                        isOn: $healthAndFitness
                    )
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Logout Card
    private var logoutCard: some View {
        SettingsCard {
            Button {
                showLogoutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 36, height: 36)

                        if session.isBusy {
                            ProgressView()
                                .tint(.red)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .font(.system(size: 16, weight: .bold))
                        }
                    }

                    Text(session.isBusy ? "Signing out..." : "Sign Out")
                        .font(TransiumFont.body(16, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.red.opacity(0.6))
                        .font(.system(size: 13, weight: .semibold))
                }
                .opacity(session.isBusy ? 0.6 : 1)
            }
            .disabled(session.isBusy)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer
    private var appFooter: some View {
        VStack(spacing: 4) {
            Text("Transium v1.0 • Bali Transit & Quests")
                .font(TransiumFont.body(12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text("Crafted for sustainable travel in Bali")
                .font(TransiumFont.body(11))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.top, 8)
    }

    // MARK: - Actions
    private func handleLogout() {
        Task {
            await session.signOut()
        }
    }
}

// MARK: - Screen-Specific Components

private struct VolumeSlider: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 13))

            Slider(value: $value, in: 0...1)
                .tint(.white)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.white)
                .font(.system(size: 14))
        }
    }
}

#Preview {
    SettingsScreen()
        .environment(SessionController())
        .environment(AppLanguageManager.shared)
        .environment(\.locale, AppLanguageManager.shared.currentLanguage.locale)
}
