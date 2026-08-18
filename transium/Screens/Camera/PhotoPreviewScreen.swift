//
//  PhotoPreviewScreen.swift
//  transium
//

import SwiftUI

struct PhotoPreviewScreen: View {
    let image: UIImage
    var onRetake: () -> Void
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSavedToast: Bool = false

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1, contentMode: .fill)
                    .padding(.horizontal, 24)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white, lineWidth: 4)
                            .padding(.horizontal, 24)
                    )
                    .padding(.horizontal, 4)

                Spacer(minLength: 12)

                actionButtons

                Spacer(minLength: 20)
            }
            .padding(.top, 20)

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("Saved to your gallery")
                        .font(TransiumFont.body(13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text("📸")
                .font(.system(size: 40))

            Text("Your Digital Keepsake")
                .font(TransiumFont.display(26, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Looking good?")
                .font(TransiumFont.body(13))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Buttons
    private var actionButtons: some View {
        HStack(spacing: 40) {
            controlButton(icon: "square.and.arrow.down.fill", label: "Save") {
                saveToGallery()
            }

            controlButton(icon: "arrow.triangle.2.circlepath", label: "Retake") {
                onRetake()
                dismiss()
            }
        }
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(Circle())

                Text(label)
                    .font(TransiumFont.body(12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    private func saveToGallery() {
        onSave()
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    PhotoPreviewScreen(image: UIImage(systemName: "photo")!, onRetake: {}, onSave: {})
}
