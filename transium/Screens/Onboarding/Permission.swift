//
//  PermissionOnboardingScreen.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI

struct Permission: View {
    @State private var newQuestAnnouncement: Bool = true
    @State private var promotionalNotifications: Bool = true
    @State private var healthAndFitness: Bool = true

    var onSave: () -> Void = {}
    var onNotNow: () -> Void = {}

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                Image(TransiumAsset.Illustration.permissionOnboarding)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)

                Spacer(minLength: 24)

                titleSection

                Spacer(minLength: 28)

                VStack(spacing: 14) {
                    PermissionRow(
                        icon: "questionmark.circle.fill",
                        title: "New Quest Announcement",
                        subtitle: "Get trip updates, reminders, and important alerts.",
                        isOn: $newQuestAnnouncement,
                        backgroundColor: .white
                    )

                    PermissionRow(
                        icon: "bell.fill",
                        title: "Promotional Notifications",
                        subtitle: "Get trip updates, reminders, and important alerts.",
                        isOn: $promotionalNotifications,
                        backgroundColor: .white
                    )

                    PermissionRow(
                        icon: "heart.fill",
                        title: "Health & Fitness",
                        subtitle: "Track your steps and activity during your journey.",
                        isOn: $healthAndFitness,
                        backgroundColor: .white
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 28)

                actionButtons
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("Make your journey\nsmarter")
                .font(TransiumFont.display(34, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text("Turn on the permission below to get the best experience from your trip.")
                .font(TransiumFont.body(14))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Buttons
    private var actionButtons: some View {
        VStack(spacing: 20) {
            TransiumPrimaryButton(title: "Save", action: onSave)

            Button(action: onNotNow) {
                Text("Not Now")
                    .font(TransiumFont.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TransiumColor.darkBlue)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    Permission()
}
