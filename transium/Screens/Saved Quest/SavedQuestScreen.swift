//
//  SavedQuestScreen.swift
//  transium
//

import SwiftUI

struct SavedQuestScreen: View {
    @Environment(\.dismiss) private var dismiss

    private let savedQuests: [DetailPlaceScreen.Quest] = [
        DetailPlaceScreen.Quest(
            imageName: "kintamani",
            title: "Sanoored",
            description: "Enjoy the vibe along the shore of Sanur",
            points: 10,
            theme: .blue
        ),
        DetailPlaceScreen.Quest(
            imageName: "traveling",
            title: "Gela-tour",
            description: "Gelato + Sanur weather = perfect summer",
            points: 10,
            theme: .red
        ),
        DetailPlaceScreen.Quest(
            imageName: "gwk",
            title: "Little Stalls",
            description: "Go local by enjoying snacks from small businesses",
            points: 10,
            theme: .green
        )
    ]

    var body: some View {
        ZStack(alignment: .top) {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(savedQuests) { quest in
                            QuestRow(quest: quest)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Saved Quest")
                .font(TransiumFont.display(22, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("Back")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(TransiumColor.primaryBlue)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    SavedQuestScreen()
}
