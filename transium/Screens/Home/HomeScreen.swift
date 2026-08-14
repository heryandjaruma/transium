//
//  HomeScreen.swift
//  transium
//

import SwiftUI

/// Intentionally bare: this exists to prove the session survived the round trip
/// to `transium-api` and to give the user a way back out. Real content lands
/// here later.
struct HomeScreen: View {
    @Environment(SessionController.self) private var session

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("You're in")
                        .font(TransiumFont.display(52))
                        .foregroundStyle(.white)

                    Text(greeting)
                        .font(TransiumFont.body(17))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(TransiumFont.body(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                TransiumPrimaryButton(
                    title: session.isBusy ? "Signing out…" : "Log out",
                    backgroundColor: .white,
                    foregroundColor: .black
                ) {
                    Task { await session.signOut() }
                }
                .disabled(session.isBusy)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var greeting: String {
        guard let profile = session.profile else {
            return "Signed in to Transium."
        }

        return "Signed in as \(profile.firstName)."
    }
}

#Preview {
    HomeScreen()
        .environment(SessionController())
}
