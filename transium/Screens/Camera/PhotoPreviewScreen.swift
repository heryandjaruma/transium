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

                photoPreview
                    .padding(.horizontal, 24)

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

    // MARK: - Photo Preview

    private var photoPreview: some View {
        // GeometryReader di sini hanya untuk membaca lebar area yang tersedia
        // (sudah dikurangi horizontal padding lewat modifier .padding di luar),
        // jadi tidak perlu UIScreen.main sama sekali.
        
        ZStack {
            GeometryReader { proxy in
                let side = proxy.size.width

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white, lineWidth: 4)
                    )
            }
            .aspectRatio(1, contentMode: .fit) // memaksa GeometryReader punya tinggi = lebar (persegi)
            
            Image("Star1")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .offset(x: 160, y: -160)
            
            Image("Star2")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .offset(x: -140, y: 170)
        
        }

    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text("📸")
                .font(.system(size: 48))
            
            ZStack {
                Image("Splash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .offset(x: 120, y: -20)
                
                Text("Looking Good?")
                    .font(TransiumFont.display(37, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }

            Text("You can retake, by pressing the retake button~")
                .font(TransiumFont.body(14))
                .foregroundColor(.white)
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
                    .font(.system(size: 25, weight: .medium))
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
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
    let dummyImage = renderer.image { ctx in
        UIColor.systemTeal.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
    }
    return PhotoPreviewScreen(image: dummyImage, onRetake: {}, onSave: {})
}
