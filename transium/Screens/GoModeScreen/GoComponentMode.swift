//
//  GoComponentMode.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 20/08/26.
//
//  Screen that assembles the reusable pieces from GoComponents.swift.
//  Swap `Color(.systemGray5)` for the real `LocalBaliMapView` when wiring
//  this into HomeScreen's navigation mode.

import SwiftUI

struct GoComponentMode: View {
    enum Variant {
        case walking
        case commute
        case commuteOnGoing
    }

    var variant: Variant = .walking
    var isMuted: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGray5)
                .ignoresSafeArea()

            VStack {
                GoTopBar(
                    onBack: {},
                    onEnd: {},
                    onLocate: {},
                    isMuted: isMuted,
                    onToggleMute: {}
                )
                .padding(.top, 6)

                Spacer()

                bottomPanel
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        switch variant {
        case .walking:
            // Cuma 1 metrik: "5 min"
            GoBottomPanel(
                livePill: nil,
                card: AnyView(
                    GoStepCard(
                        mode: .walking,
                        verb: "Walk to",
                        destination: "Sanur Beach",
                        metrics: [.init("15", "min"), .init("1.2", "kilometer")]
                    )
                ),
                onTripDetails: {}
            )

        case .commute:
            GoBottomPanel(
                livePill: (
                    title: "Check Bus Live Location",
                    subtitle: "Open Trans Metro Dewata",
                    action: {}
                ),
                card: AnyView(
                    GoBusAppCard(
                        providerCode: "KIB",
                        promptText: "Check bus live location on",
                        appName: "Trans Metro Dewata App",
                        downloadLabel: "Download TMD App",
                        onDownload: {}
                    )
                ),
                onTripDetails: {}
            )

        case .commuteOnGoing:
            // 2 metrik sekaligus: "15 min · 1.2 kilometer"
            GoBottomPanel(
                livePill: (
                    title: "Check Bus Live Location",
                    subtitle: "Open Trans Metro Dewata",
                    action: {}
                ),
                card: AnyView(
                    GoStepCard(
                        mode: .bus(providerCode: "KIB"),
                        verb: "Ride to",
                        destination: "Jimbaran Side Walk",
                        metrics: [
                            .init("15", "min"),
                            .init("1.2", "kilometer")
                        ]
                    )
                ),
                onTripDetails: {}
            )
        }
    }
}

#Preview("Walking") {
    GoComponentMode(variant: .walking)
}

#Preview("Commute") {
    GoComponentMode(variant: .commute)
}

#Preview("Commute On Going") {
    GoComponentMode(variant: .commuteOnGoing)
}
