//
//  PageIndicator.swift
//  transium
//

import SwiftUI

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { page in
                let isCurrentPage = page == currentPage

                Capsule()
                    .fill(isCurrentPage ? Color.white : Color.white.opacity(0.25))
                    .frame(width: page == currentPage ? 16 : 8, height: 8)
                    .scaleEffect(isCurrentPage ? 1 : 0.92)
                    .animation(.smooth(duration: 0.26, extraBounce: 0), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

#Preview {
    ZStack {
        TransiumColor.primaryBlue
            .ignoresSafeArea()

        PageIndicator(currentPage: 0, totalPages: 3)
    }
}
