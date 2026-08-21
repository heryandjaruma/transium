//
//  HomeBottomTicketCarousel.swift
//  transium
//

import CoreLocation
import SwiftUI

struct HomeBottomTicketCarousel: View {
    let kelurahanGroups: [KelurahanQuestsGroup]
    @Binding var visibleTicketPage: Int?
    let currentLocationLabel: String
    let currentLocation: CLLocation
    var onSelectKelurahan: (Kelurahan) -> Void
    var onEditLocation: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ticketRail
            
            ticketPageIndicator
                .padding(.bottom, 6)
            
            currentLocationPill
        }
        .padding(.bottom, 24)
    }

    private var ticketRail: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 14) {
                if !kelurahanGroups.isEmpty {
                    ForEach(Array(kelurahanGroups.enumerated()), id: \.offset) { index, group in
                        let variant: TransiumTicketVariant = (index % 3 == 0) ? .blue : ((index % 3 == 1) ? .mint : .coral)
                        let isRecommended = (index == 0)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if isRecommended {
                                TransiumRecommendedSeal(style: .ticketTab)
                                    .padding(.leading, 8)
                                    .padding(.bottom, -12)
                                    .zIndex(1)
                            }
                            
                            TransiumTicketCard(
                                title: group.kelurahan.kelurahanName,
                                subtitle: group.kelurahan.description ?? group.quests.first?.description ?? "\(group.kelurahan.kecamatanName), Bali",
                                distance: HomeLocationHelper.distanceText(for: group, currentLocation: currentLocation),
                                price: "Rp. 4,4k",
                                imageUrl: group.kelurahan.thumbnails.first?.url ?? group.quests.first?.thumbnails.first?.url,
                                fallbackImageName: isRecommended ? "kintamani" : "sanoored",
                                variant: variant
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectKelurahan(group.kelurahan)
                            }
                        }
                        .frame(width: 336)
                        .id(index)
                    }
                } else {
                    ForEach(0..<2, id: \.self) { index in
                        let isRecommended = (index == 0)
                        let variant: TransiumTicketVariant = isRecommended ? .blue : .mint

                        VStack(alignment: .leading, spacing: 0) {
                            if isRecommended {
                                TransiumRecommendedSeal(style: .ticketTab)
                                    .padding(.leading, 10)
                                    .padding(.bottom, -8)
                                    .zIndex(1)
                            }

                            TransiumTicketSkeletonCard(variant: variant)
                        }
                        .frame(width: 336)
                        .id(index)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: kelurahanGroups.isEmpty)
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .frame(height: 190)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visibleTicketPage)
        .accessibilityLabel("Recommended destinations")
    }

    private var ticketPageIndicator: some View {
        PageIndicator(
            currentPage: visibleTicketPage ?? 0,
            totalPages: max(kelurahanGroups.count, 2),
            activeColor: TransiumColor.primaryBlue,
            inactiveColor: TransiumColor.ticketInk.opacity(0.26)
        )
        .accessibilityLabel("Ticket \(min((visibleTicketPage ?? 0) + 1, max(kelurahanGroups.count, 2))) of \(max(kelurahanGroups.count, 2))")
    }

    private var currentLocationPill: some View {
        Button(action: onEditLocation) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)

                Text(currentLocationLabel)
                    .font(TransiumFont.body(14, weight: .semibold))
                    .foregroundStyle(TransiumColor.ticketInk)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.92))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.transiumNoOpacity)
        .padding(.horizontal, 20)
    }
}
