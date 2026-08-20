//
//  ReportCard.swift
//  transium
//
//  Created by Beatrice Deviana on 19/08/26.
//

import SwiftUI

struct ComponentSummary: View {

    let origin: String
    let destination: String
    let cards: [StatCardData]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(origin: String = "Jimbaran", destination: String = "Sanur Beach", cards: [StatCardData]) {
        self.origin = origin
        self.destination = destination
        self.cards = cards
    }

    var body: some View {
        ZStack {
            Color.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 16) {
                routePill

                statsGrid
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding()
        }
    }

    // MARK: - Route Pill
    // Pola pill yang sama seperti "Sanur Street" di SummaryScreen_1,
    // tapi dengan 2 titik (origin → destination) alih-alih 1 lokasi tunggal.

    private var routePill: some View {
        HStack(spacing: 6) {
            Image("RedPoint")
                .resizable()
                .frame(width: 12, height: 12)

            Text(origin)
                .font(TransiumFont.body(12).weight(.semibold))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))

            Image("GreenPoint")
                .resizable()
                .frame(width: 12, height: 12)

            Text(destination)
                .font(TransiumFont.body(12).weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(10)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 8)

            LazyVGrid(columns: columns) {
                ForEach(cards) { SummaryBox(data: $0) }
            }
        }
    }
}

#Preview {
    ComponentSummary(cards: [
        StatCardData(title: "Total Distance", value: "17", unit: "km",
                     icon: "distance-icon"),
        StatCardData(title: "Cost Total", value: "4.4k", unit: "Rp",
                     icon: "cost-icon"),
        StatCardData(title: "Calorie Burn", value: "2500", unit: nil,
                     icon: "calorie-icon"),
        StatCardData(title: "Total Steps", value: "3600", unit: nil,
                     icon: "steps-icon")
    ])
}
