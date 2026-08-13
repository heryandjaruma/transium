//
//  PageIndicator.swift
//  transium
//
//  Created by Awfar on 13/08/26.
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
                    .frame(
                        width: page == currentPage ? 16 : 8,
                        height: 8
                    )
            }
        }
    }
}

#Preview {
    ZStack {
        Color("PrimaryBlue")
            .ignoresSafeArea()

        PageIndicator(
            currentPage: 0,
            totalPages: 3
        )
    }
}
