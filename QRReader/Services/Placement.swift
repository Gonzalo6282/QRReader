import SliceAnalytics
import SlicePurchases

/// Superwall placements (Build Doc paywall table + `settings_upgrade` from the mockup).
enum Placement: String, PaywallPlacementType, CaseIterable {
    case onboardingEnd = "onboarding_end"
    case scanResultAction = "scan_result_action"
    case qrCreateSave = "qr_create_save"
    case historyOpen = "history_open"
    case batchScan = "batch_scan"
    case settingsUpgrade = "settings_upgrade"

    /// Soft paywalls can be closed (after 2.5 s at onboarding); the rest are hard and offer the trial.
    var isSoft: Bool { self == .onboardingEnd || self == .settingsUpgrade }
}

extension PaywallService {
    /// `gate(.scanResultAction) { … }` at call sites.
    func gate(_ placement: Placement, onFinished: (() -> Void)? = nil, feature: @escaping () -> Void) {
        gate(placement as any PaywallPlacementType, params: [:], onFinished: onFinished, feature: feature)
    }
}

/// Firebase events (Build Doc "Tracking" + mockup extras). Trial and purchase events come from RevenueCat.
enum Event: String, AnalyticsEventType {
    case onboardingComplete = "onboarding_complete"
    case cameraPermission = "camera_permission"
    case scanSuccess = "scan_success"
    case paywallView = "paywall_view"
    case qrCreated = "qr_created"
    case resultAction = "result_action"
    case consent
    case supportEmail = "support_email"
}

enum Track {
    /// Sends nothing without the Firebase file or without consent (SliceAnalytics).
    static func log(_ event: Event, _ parameters: [String: Any] = [:]) {
        AppAnalytics.shared.log(event as any AnalyticsEventType, parameters)
    }
}
