//
//  BackButton.swift
//  transium
//
//  Created by Awfar on 13/08/26.
//

import SwiftUI

struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
        }
    }
}
