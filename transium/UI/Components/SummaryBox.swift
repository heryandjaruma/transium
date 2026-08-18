//
//  SummaryBox.swift
//  transium
//
//  Created by Beatrice Deviana on 18/08/26.
//

import SwiftUI
import Observation

//@Observable
//class StatsViewModel {
//    var cards: [StatCardData] = []
//
//    func load(for questID: String) async {
//        let distance = await healthKitService.distance(for: questID)
//        let cost = await walletService.cost(for: questID)
//        let calories = await healthKitService.calories(for: questID)
//        let steps = await pedometerService.steps(for: questID)
//
//        cards = [
//            StatCardData(title: "Total Distance", value: "\(distance)", unit: "km", icon: "figure.walk"),
//            StatCardData(title: "Cost Total", value: "\(cost)", unit: "Rp", icon: "banknote"),
//            StatCardData(title: "Calorie Burn", value: "\(calories)", unit: nil, icon: "flame.fill"),
//            StatCardData(title: "Total Steps", value: "\(steps)", unit: nil, icon: "shoeprints.fill"),
//        ]
//    }
//}

//extension StatsViewModel {
//    static var sample: StatsViewModel {
//        let dummy = StatsViewModel()
//        dummy.cards = [
//            StatCardData(title: "Total Distance", value: "17", unit: "km", icon: "figure.walk"),
//            StatCardData(title: "Cost Total", value: "4.4K", unit: "Rp", icon: "banknote"),
//            StatCardData(title: "Calorie Burn", value: "2500", unit: nil, icon: "flame.fill"),
//            StatCardData(title: "Total Steps", value: "3600", unit: nil, icon: "shoeprints.fill"),
//        ]
//        return dummy
//    }
//}

// MARK: - Shared data model
struct StatCardData: Identifiable {
    let id = UUID()
    let title: String
    let value: String        // angka2 dinamis momz (calories, km etc)
    let unit: String?
    let icon: String
}

// MARK: - Reusable card view
struct SummaryBox: View {
    let data: StatCardData

    var body: some View {
        HStack(spacing: 15) {
            Image(data.icon)
                .resizable()
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(TransiumFont.body(12))
                    .foregroundStyle(.black)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let unit = data.unit, unit == "Rp" {
                        Text(unit).font(TransiumFont.display(15))
                    }
                    Text(data.value)
                        .font(TransiumFont.display(25))
                    if let unit = data.unit, unit != "Rp" {
                        Text(unit)
                            .font(TransiumFont.display(15))
                    }
                }
            }
        }
        .padding()
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
