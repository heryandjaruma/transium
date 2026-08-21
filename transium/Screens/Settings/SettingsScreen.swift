//
//  SettingsScreen.swift
//  transium
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionController.self) private var session

    @State private var selectedLanguage: Language = .indonesia
    @State private var voiceVolume: Double = 0.6
    @State private var musicVolume: Double = 0.5
    @State private var isPermissionExpanded: Bool = false

    @State private var newQuestAnnouncement: Bool = true
    @State private var promotionalNotifications: Bool = true
    @State private var healthAndFitness: Bool = true

    @State private var showLogoutConfirmation: Bool = false

    enum Language: String, CaseIterable {
        case indonesia = "Bahasa Indonesia"
        case english = "English"

        var flag: String {
            switch self {
            case .indonesia: "🇮🇩"
            case .english: "🇺🇸"
            }
        }
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
                    dismiss()
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
            SettingsSectionLabel(icon: "translate", title: "Language")

            HStack(spacing: 6) {
                ForEach(Language.allCases, id: \.self) { language in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedLanguage = language
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.flag)
                                .font(.system(size: 18))
                            Text(language.rawValue)
                                .font(TransiumFont.body(15, weight: selectedLanguage == language ? .bold : .medium))
                                .foregroundColor(selectedLanguage == language ? TransiumColor.primaryBlue : .white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selectedLanguage == language ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .shadow(color: selectedLanguage == language ? Color.black.opacity(0.1) : .clear, radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.15))
            .clipShape(Capsule())
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
}
