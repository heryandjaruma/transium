//
//  PageIndicator.swift
//  transium
//

import SwiftUI

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let activeColor: Color
    let inactiveColor: Color

    init(
        currentPage: Int,
        totalPages: Int,
        activeColor: Color = .white,
        inactiveColor: Color = .white.opacity(0.25)
    ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { page in
                let isCurrentPage = page == currentPage

                Capsule()
                    .fill(isCurrentPage ? activeColor : inactiveColor)
                    .frame(width: page == currentPage ? 16 : 8, height: 8)
                    .scaleEffect(isCurrentPage ? 1 : 0.92)
                    .animation(pageAnimation(for: page), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }

    private func pageAnimation(for page: Int) -> Animation {
        .smooth(duration: 0.26, extraBounce: 0)
            .delay(Double(page) * 0.025)
    }
}

#Preview {
    ZStack {
        TransiumColor.primaryBlue
            .ignoresSafeArea()

        PageIndicator(currentPage: 0, totalPages: 3)
    }
}
