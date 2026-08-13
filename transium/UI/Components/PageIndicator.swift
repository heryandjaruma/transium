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
                Capsule()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.25))
                    .frame(width: page == currentPage ? 16 : 8, height: 8)
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
