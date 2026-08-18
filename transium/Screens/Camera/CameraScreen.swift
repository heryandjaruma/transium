//
//  CameraScreen.swift
//  transium
//

import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = CameraModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                cameraPreview

                Text("Press to take photo")
                    .font(TransiumFont.body(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                controls

                Spacer(minLength: 12)
            }
            .padding(.top, 20)
        }
        .onAppear {
            camera.checkPermission()
        }
        .onDisappear {
            camera.stopSession()
        }
        .alert("Camera Access Needed", isPresented: $camera.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to take photos.")
        }
        .fullScreenCover(isPresented: Binding(
            get: { camera.capturedImage != nil },
            set: { if !$0 { camera.capturedImage = nil } }
        )) {
            if let image = camera.capturedImage {
                PhotoPreviewScreen(
                    image: image,
                    onRetake: {
                        camera.retake()
                    },
                    onSave: {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text("📸")
                .font(.system(size: 40))

            Text("Capture Your Moment")
                .font(TransiumFont.display(26, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Your digital keepsake~")
                .font(TransiumFont.body(13))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Camera Preview
    private var cameraPreview: some View {
        Group {
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
            } else {
                Color.black.opacity(0.3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 24)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white, lineWidth: 4)
                .padding(.horizontal, 24)
        )
        .padding(.horizontal, 4)
    }

    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 48) {
            controlButton(
                icon: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                label: "Flash"
            ) {
                camera.toggleFlash()
            }

            Button {
                camera.capturePhoto()
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 78, height: 78)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 8)
                            .frame(width: 96, height: 96)
                    )
            }

            controlButton(icon: "arrow.triangle.2.circlepath.camera", label: "Flip") {
                camera.flipCamera()
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
}

#Preview {
    CameraScreen()
}

#Preview {
//    PhotoPreviewScreen(image: UIImage, onRetake: <#T##() -> Void#>, onSave: <#T##() -> Void#>)
}
