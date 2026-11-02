import AVFoundation
import Foundation
import CoreImage
import ScanKit
import Vision

/// The live scanner: AVFoundation's fast barcode reader, plus Vision on every few frames
/// (alternating normal and inverted) so white-on-black and damaged codes are read too.
/// Runs on its own queues; `onCode` is called once per new code until `resume()`.
nonisolated final class CameraScanner: NSObject, @unchecked Sendable,
    AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onCode: (@Sendable (ScannedCode) -> Void)?

    private let sessionQueue = DispatchQueue(label: "qodi.camera.session")
    private let outputQueue = DispatchQueue(label: "qodi.camera.output")
    private let lock = NSLock()
    private var paused = false
    private var lastRaw = ""
    private var lastTime = Date.distantPast
    private var frame = 0
    private var device: AVCaptureDevice?
    private let ciContext = CIContext()

    static let metadataTypes: [AVMetadataObject.ObjectType] = [
        .qr, .ean13, .ean8, .upce, .code128, .code39, .dataMatrix, .pdf417, .aztec,
    ]

    /// Sets up the back camera. Safe to call once; does nothing without a camera (simulator).
    func configure() {
        sessionQueue.async { [self] in
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device)
            else { return }
            self.device = device
            session.beginConfiguration()
            session.sessionPreset = .high
            if session.canAddInput(input) { session.addInput(input) }
            let metadata = AVCaptureMetadataOutput()
            if session.canAddOutput(metadata) {
                session.addOutput(metadata)
                metadata.setMetadataObjectsDelegate(self, queue: outputQueue)
                metadata.metadataObjectTypes = Self.metadataTypes.filter(metadata.availableMetadataObjectTypes.contains)
            }
            let video = AVCaptureVideoDataOutput()
            video.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(video) {
                session.addOutput(video)
                video.setSampleBufferDelegate(self, queue: outputQueue)
            }
            session.commitConfiguration()
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
        }
    }

    func start() {
        sessionQueue.async { [self] in if !session.isRunning { session.startRunning() } }
    }

    func stop() {
        sessionQueue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    /// Ready for the next code (after the result card closes, or straight away in batch mode).
    func resume() {
        lock.withLock { paused = false }
    }

    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    func setZoom(_ factor: CGFloat, animated: Bool) {
        sessionQueue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            let clamped = max(1, min(factor, min(device.activeFormat.videoMaxZoomFactor, 8)))
            if animated { device.ramp(toVideoZoomFactor: clamped, withRate: 8) } else { device.videoZoomFactor = clamped }
            device.unlockForConfiguration()
        }
    }

    // MARK: - Delivery

    private func deliver(raw: String, format: BarcodeFormat) {
        let accept: Bool = lock.withLock {
            guard !paused else { return false }
            // The same code again within 2 s is the same scan.
            if raw == lastRaw, Date.now.timeIntervalSince(lastTime) < 2 { return false }
            paused = true
            lastRaw = raw
            lastTime = .now
            return true
        }
        if accept { onCode?(ScannedCode(raw: raw, format: format)) }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for case let code as AVMetadataMachineReadableCodeObject in objects {
            guard let raw = code.stringValue, !raw.isEmpty, let format = BarcodeFormat(systemName: code.type.rawValue) else { continue }
            deliver(raw: raw, format: format)
            return
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frame += 1
        guard frame % 6 == 0, !lock.withLock({ paused }), let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: pixels)
        if frame % 12 == 0, let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: image])?.outputImage {
            image = inverted
        }
        guard let cg = ciContext.createCGImage(image, from: image.extent), let found = PhotoScanner.codes(in: cg, tryInverted: false).first
        else { return }
        deliver(raw: found.raw, format: found.format)
    }
}
