//
//  PaymentMethodScreen.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI

struct PaymentMethod: View {
    var onOK: () -> Void = {}

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                Image(TransiumAsset.Illustration.payment)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)

                Spacer(minLength: 24)

                titleSection

                Spacer(minLength: 28)

                VStack(spacing: 10) {
                    PaymentMethodRow(
                        icon: "creditcard.fill",
                        title: "E-money Card",
                        subtitle: "Flazz, Brizzi, TapCash, etc. Get one at the nearest minimart"
                    )

                    PaymentMethodRow(
                        icon: "qrcode",
                        title: "QRIS",
                        subtitle: "Accessible through your banking/e-money app"
                    )

                    PaymentMethodRow(
                        iconImage: TransiumAsset.Logo.tmd,
                        title: "TMD-Pass LAIT",
                        subtitle: "Accessible through the Trans Metro Dewata app"
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 28)

                TransiumPrimaryButton(title: "OK", action: onOK)
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("Prepare your\npayment method")
                .font(TransiumFont.display(34, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text("You have to prepare one of these options:")
                .font(TransiumFont.body(14))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PaymentMethod()
}
