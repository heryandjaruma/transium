//
//  TripDetailsSheet.swift
//  transium
//
//  Modal presentation of the same step timeline used in the pre-Go overview
//  (StepTimelineView, from NavigationBottomSheet.swift), reused for the
//  "Trip Details" tap in Go Mode.

import SwiftUI

struct TripDetailsSheet: View {
    let journey: JourneyResult
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Trip Details")
                    .font(TransiumFont.body(20, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.transiumNoOpacity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                StepTimelineView(journey: journey)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
