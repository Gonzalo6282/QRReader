import AVFoundation
import Observation
import ScanKit

/// Camera permission, torch, zoom and the "locked on a code" state for the scanner screen.
@Observable
final class CameraController {
    let scanner = CameraScanner()
    var permission: AVAuthorizationStatus
    var torchOn = false {
        didSet { scanner.setTorch(torchOn) }
    }
    private(set) var zoom: CGFloat = 1
    private(set) var locked = false
    @ObservationIgnored var onCode: ((ScannedCode) -> Void)?
    @ObservationIgnored private var configured = false

    init() {
        // UI tests can't answer the system prompt: they see the "camera off" screen.
        permission = AppConfig.isUITesting ? .denied : AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isDenied: Bool { permission == .denied || permission == .restricted }

    func appear() async {
        if permission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .denied
            Track.log(.cameraPermission, ["result": granted ? "granted" : "denied"])
        }
        guard permission == .authorized else { return }
        if !configured {
            configured = true
            scanner.onCode = { [weak self] code in
                Task { @MainActor in self?.found(code) }
            }
            scanner.configure()
        }
        scanner.start()
    }

    func disappear() {
        torchOn = false
        scanner.stop()
    }

    func resume() {
        locked = false
        scanner.resume()
    }

    func setZoom(_ factor: CGFloat, animated: Bool) {
        zoom = max(1, min(factor, 8))
        scanner.setZoom(zoom, animated: animated)
    }

    private func found(_ code: ScannedCode) {
        locked = true
        Feedback.scanned()
        onCode?(code)
    }
}
