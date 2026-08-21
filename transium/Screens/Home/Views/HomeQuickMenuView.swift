//
//  HomeQuickMenuView.swift
//  transium
//

import SwiftUI

struct HomeQuickMenuView: View {
    @Binding var isMenuExpanded: Bool
    var onSettings: () -> Void
    var onProfile: () -> Void
    var onSavedQuests: () -> Void
    var onLocate: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TransiumIconButton(
                systemName: isMenuExpanded ? "xmark" : "ellipsis",
                accessibilityLabel: "Menu",
                size: 44
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isMenuExpanded.toggle()
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            
            if isMenuExpanded {
                TransiumIconButton(
                    systemName: "gearshape.fill",
                    accessibilityLabel: "Settings",
                    size: 44
                ) {
                    withAnimation { isMenuExpanded = false }
                    onSettings()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
                
                TransiumIconButton(
                    systemName: "person.crop.circle.fill",
                    accessibilityLabel: "Profile Button",
                    size: 44
                ) {
                    withAnimation { isMenuExpanded = false }
                    onProfile()
                }
                
                TransiumIconButton(
                    systemName: "bookmark.fill",
                    accessibilityLabel: "Saved quests",
                    size: 44
                ) {
                    withAnimation { isMenuExpanded = false }
                    onSavedQuests()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
            }
            
            TransiumIconButton(
                icon: .asset("focus"),
                accessibilityLabel: "Center map on your location",
                size: 44
            ) {
                onLocate()
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
