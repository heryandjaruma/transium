//
//  TripDetailsSheet.swift
//  transium
//
//  Modal presentation of the exact same route-summary component shown docked
//  at the bottom of the pre-Go overview (NavigationBottomSheet) — reused
//  as-is for the "Trip Details" tap in Go Mode, just inside a system sheet
//  instead of docked to the screen.

import SwiftUI

struct TripDetailsSheet: View {
    let journey: JourneyResult
    let onClose: () -> Void

    var body: some View {
        NavigationBottomSheet(journey: journey, onBack: onClose)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
    }
}
