//
//  CameraModel.swift
//  transium
//

import AVFoundation
import UIKit
import SwiftUI
import Combine

final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "transium.camera.session")

    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back

    @Published var capturedImage: UIImage? = nil
    @Published var isFlashOn: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var showPermissionAlert: Bool = false

    // MARK: - Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.showPermissionAlert = true
                    }
                }
            }
        default:
            isAuthorized = false
            showPermissionAlert = true
        }
    }

    // MARK: - Session Setup

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            self.addInput(for: self.currentPosition)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if let currentInput {
            session.removeInput(currentInput)
        }

        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
    }

    // MARK: - Actions

    func capturePhoto() {
        var settings = AVCapturePhotoSettings()
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        settings.flashMode = isFlashOn ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() {
        isFlashOn.toggle()
    }

    func flipCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.addInput(for: self.currentPosition)
            self.session.commitConfiguration()
        }
    }

    func retake() {
        capturedImage = nil
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        DispatchQueue.main.async {
            self.capturedImage = image
            self.session.stopRunning()
        }
    }
}
