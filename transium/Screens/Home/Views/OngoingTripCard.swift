//
//  OngoingTripCard.swift
//  transium
//

import SwiftUI

/// Flush-left tab surfaced on the Explore Mode map once `HomeScreen` finds the caller has a
/// `status: "started"` journey attempt (GET /private/journey/current). Tapping it resumes that
/// trip straight into Go Mode — no destination search needed, since one is already underway.
struct OngoingTripCard: View {
    let questName: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ongoing Trip")
                        .font(TransiumFont.body(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(questName)
                        .font(TransiumFont.body(20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .padding(.vertical, 14)
            .background(TransiumColor.primaryBlue)
            .clipShape(
                UnevenRoundedRectangle(cornerRadii: .init(
                        bottomTrailing: 20,
                        topTrailing: 20
                    )
                )
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.transiumNoOpacity)
        .accessibilityLabel("Ongoing trip: \(questName)")
        .accessibilityHint("Resumes your in-progress journey")
    }
}

#Preview {
    ZStack(alignment: .topLeading) {
        Color(.systemGray5).ignoresSafeArea()
        OngoingTripCard(questName: "Sanoored")
            .padding(.top, 60)
    }
}
