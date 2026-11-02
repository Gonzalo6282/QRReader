import SlicePurchases
import SliceUI
import SwiftUI

/// The app's own paywall (shown when Superwall has no campaign or isn't set up): mockup `oPaywall` wording.
enum QodiPaywall {
    static let benefits = [
        "Open links, join Wi-Fi, save contacts",
        "Save and share your own QR codes",
        "Scan in bulk and export to CSV",
        "Full scan history with search",
        "No ads, ever",
    ]

    /// The green line above the headline on hard paywalls.
    static func context(for placement: Placement?) -> String? {
        switch placement {
        case .scanResultAction: "Open, join, save and share with Pro"
        case .qrCreateSave: "Saving and sharing codes is part of Pro"
        case .historyOpen: "Your full scan history is part of Pro"
        case .batchScan: "Batch scanning is part of Pro"
        case .onboardingEnd, .settingsUpgrade, nil: nil
        }
    }

    static func content(for placementName: String) -> PaywallContent {
        let placement = Placement(rawValue: placementName)
        return PaywallContent(
            headline: "Do everything with your scans",
            subtitle: context(for: placement).map { LocalizedStringKey($0) },
            benefits: benefits,
            headerBackground: .black,
            headerForeground: .white,
            showsTrialTimeline: true,
            trialReminder: false,
            closeButtonDelay: placement?.isSoft == true ? .milliseconds(2500) : .zero,
            termsURL: AppConfig.termsURL,
            privacyURL: AppConfig.privacyURL)
    }
}

/// Presents the native paywall from whichever screen is on top (a sheet can't present from under another sheet).
struct PaywallHost: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { active ? PaywallService.shared.nativePaywall : nil },
            set: { PaywallService.shared.nativePaywall = $0 }
        )) { request in
            PaywallTemplate(request: request, content: QodiPaywall.content(for: request.placementName))
                .sliceTheme(QodiTheme.brand)
                .preferredColorScheme(.dark)
                .onDisappear { request.onClose() }
        }
    }
}

extension View {
    func paywallHost(active: Bool = true) -> some View { modifier(PaywallHost(active: active)) }
}
