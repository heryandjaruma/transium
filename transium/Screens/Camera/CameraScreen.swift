//
//  CameraScreen.swift
//  transium
//

import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = CameraModel()
    @Environment(\.dismiss) private var dismiss

    /// Called with the captured photo once the user confirms it in the preview step. Defaults
    /// to saving straight to the device's Photos library; pass a custom closure (e.g. to upload
    /// a journey photo-checkpoint) to override that. This screen doesn't dismiss itself on
    /// success — closing the flow once `onCaptured` finishes is the presenter's job (e.g. via
    /// the `item`/`isPresented` binding it used to present this screen).
    var onCaptured: (UIImage) async -> Void = { image in
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 24) {
                closeButton

                header

                cameraPreview

                Text("Press to take photo")
                    .font(TransiumFont.body(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                controls

                Spacer(minLength: 12)
            }
            .padding(.top, 8)
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
                        await onCaptured(image)
                    }
                )
            }
        }
    }

    // MARK: - Close

    /// This is presented over an optional (skippable) step, so the user always has a way out
    /// without taking a photo — `.fullScreenCover` offers no swipe-to-dismiss of its own.
    private var closeButton: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
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
                    .offset(x: 160, y: -20)
                Text("Capture Your Moment")
                    .font(TransiumFont.display(37, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }

            Text("Your digital keepsake~")
                .font(TransiumFont.body(14))
                .foregroundColor(.white)
        }
    }

    // MARK: - Camera Preview
    private var cameraPreview: some View {
        ZStack {
            Group {
                if camera.isAuthorized {
                    CameraPreviewView(session: camera.session)
                } else {
                    Color.black.opacity(0.3)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white, lineWidth: 4)
            )
            .padding(.horizontal, 24)

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
