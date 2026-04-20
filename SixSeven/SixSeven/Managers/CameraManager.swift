import AVFoundation
import UIKit

/// Manages the AVCaptureSession for front-facing camera.
/// Delivers CMSampleBuffer frames to a delegate on a background queue.
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.sixseven.camera", qos: .userInitiated)
    private var videoOutput = AVCaptureVideoDataOutput()

    var onFrame: ((CMSampleBuffer) -> Void)?

    @Published var isRunning = false

    func configure() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Front camera
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) else {
            print("[CameraManager] No front camera available")
            session.commitConfiguration()
            return
        }

        // Optimize for 60 FPS
        do {
            try device.lockForConfiguration()
            let targetFPS = CMTimeMake(value: 1, timescale: 60)
            if let range = device.activeFormat.videoSupportedFrameRateRanges.first(
                where: { $0.maxFrameRate >= 60 }
            ) {
                device.activeVideoMinFrameDuration = targetFPS
                device.activeVideoMaxFrameDuration = targetFPS
                _ = range // suppress unused warning
            } else {
                // Fallback to 30 FPS
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            }
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Could not configure frame rate: \(error)")
        }

        // Input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            print("[CameraManager] Cannot create input: \(error)")
            session.commitConfiguration()
            return
        }

        // Output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Mirror front camera
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
            connection.videoRotationAngle = 90
        }

        session.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
