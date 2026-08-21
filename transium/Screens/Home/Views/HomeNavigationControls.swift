//
//  HomeNavigationControls.swift
//  transium
//

import SwiftUI

struct HomeNavigationTopBar: View {
    var hasActiveAttempt: Bool
    var isCancelingJourney: Bool
    var isBookmarked: Bool
    var isTogglingBookmark: Bool
    var onBack: () -> Void
    var onCancelAttempt: () -> Void
    var onToggleBookmark: () -> Void
    var onShare: () -> Void
    var onLocate: () -> Void

    var body: some View {
        HStack {
            TransiumIconButton(
                systemName: "arrow.left",
                accessibilityLabel: "Back",
                size: 44
            ) {
                onBack()
            }
            
            Spacer()

            HStack(spacing: 12) {
                if hasActiveAttempt {
                    TransiumIconButton(
                        systemName: "xmark",
                        accessibilityLabel: "Cancel journey",
                        backgroundColor: TransiumColor.lightRed,
                        foregroundColor: .white,
                        size: 44
                    ) {
                        onCancelAttempt()
                    }
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .disabled(isCancelingJourney)
                }

                TransiumIconButton(
                    systemName: isBookmarked ? "bookmark.fill" : "bookmark",
                    accessibilityLabel: isBookmarked ? "Remove bookmark" : "Save route",
                    foregroundColor: isBookmarked ? TransiumColor.primaryBlue : .black,
                    size: 44
                ) {
                    onToggleBookmark()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .disabled(isTogglingBookmark)

                TransiumIconButton(
                    systemName: "square.and.arrow.up",
                    accessibilityLabel: "Share route",
                    size: 44
                ) {
                    onShare()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                
                TransiumIconButton(
                    icon: .asset("focus"),
                    accessibilityLabel: "Center map on route",
                    size: 44
                ) {
                    onLocate()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 20)
    }
}

struct HomeNavigationBottomStack: View {
    let journey: JourneyResult
    var isStartingGoMode: Bool
    var onStartGo: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onStartGo) {
                    HStack(spacing: 8) {
                        Text("Go")
                            .font(TransiumFont.body(17, weight: .bold))
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.24, green: 0.65, blue: 0.44))
                    .cornerRadius(28)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .disabled(isStartingGoMode)
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            
            NavigationBottomSheet(journey: journey, onBack: onBack)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
    }
}
