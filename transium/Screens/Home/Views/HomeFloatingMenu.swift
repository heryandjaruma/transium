//
//  HomeFloatingMenu.swift
//  transium
//

import SwiftUI

struct HomeFloatingMenu: View {
    @Binding var isExpanded: Bool
    var onSettings: () -> Void
    var onProfile: () -> Void
    var onSavedQuests: () -> Void
    var onCenterMap: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TransiumIconButton(
                systemName: isExpanded ? "xmark" : "ellipsis",
                accessibilityLabel: "Menu",
                size: 44
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            
            if isExpanded {
                TransiumIconButton(
                    systemName: "gearshape.fill",
                    accessibilityLabel: "Settings",
                    size: 44
                ) {
                    withAnimation { isExpanded = false }
                    onSettings()
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
                
                TransiumIconButton(
                    systemName: "person.crop.circle.fill",
                    accessibilityLabel: "Profile Button",
                    size: 44
                ) {
                    withAnimation { isExpanded = false }
                    onProfile()
                }
                
                TransiumIconButton(
                    systemName: "bookmark.fill",
                    accessibilityLabel: "Saved quests",
                    size: 44
                ) {
                    withAnimation { isExpanded = false }
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
                onCenterMap()
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
