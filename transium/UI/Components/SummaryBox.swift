//
//  SummaryBox.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI

// MARK: - Shared data model
struct StatCardData: Identifiable {
    let id = UUID()
    let title: String
    let value: String        // "17", "4.4K", "2500", "3600"
    let unit: String?        // "km", "Rp", nil, nil
    let icon: String         // SF Symbol or custom asset name
}

// MARK: - Reusable card view
struct SummaryBox: View {
    let data: StatCardData

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 56, height: 56)
                Image(data.icon)
                    .resizable()
                    .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(TransiumFont.body(15))
                    .foregroundStyle(.black)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let unit = data.unit, unit == "Rp" {
                        Text(unit).font(TransiumFont.display(18))
                    }
                    Text(data.value)
                        .font(.system(size: 30, weight: .heavy))
                    if let unit = data.unit, unit != "Rp" {
                        Text(unit)
                            .font(TransiumFont.display(18))
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// MARK: - Grid of cards
struct StatsGridView: View {
    let cards: [StatCardData]
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cards) { SummaryBox(data: $0) }
        }
        .padding(16)
    }
}

#Preview {
    ZStack {
        
        Color.primaryBlue
            .ignoresSafeArea()
        
        SummaryBox(data: StatCardData(
            title: "Total Distance",
            value: "17",
            unit: "km",
            icon: "distance-icon",
        ))
        .padding()
        .background(TransiumColor.primaryBlue)
    }
}
