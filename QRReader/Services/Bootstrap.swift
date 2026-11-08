import Foundation
import SliceAnalytics
import SlicePurchases
import SliceUI

/// Library set-up at launch, in the order the SliceLibrary READMEs give.
enum Bootstrap {
    static func start() {
        SettingsKey.registerDefaults()
        SliceTheme.appDefault = QodiTheme.main
        AppAnalytics.shared.configure(AnalyticsConfig(
            consentKey: SettingsKey.analytics,
            consentPolicy: .askInEuropeOnly,
            remoteDefaults: ["onboarding_soft_paywall": .bool(true)]))
        PurchaseManager.shared.configure(PurchaseConfig(
            revenueCatAPIKey: AppKey.infoPlist("RevenueCatAPIKey", prefix: "appl_"),
            entitlement: AppConfig.entitlement,
            productIDs: AppConfig.productIDs,
            forcePremium: AppConfig.arguments.contains("-premium")))
        PaywallService.shared.onPaywallShown = { placement, paywallID in
            Track.log(.paywallView, ["placement": placement, "paywall_id": paywallID])
        }
        PaywallService.shared.configure(superwallAPIKey: AppKey.infoPlist("SuperwallAPIKey", prefix: "pk_"))
        if !UserDefaults.standard.bool(forKey: SettingsKey.onboarded) { Track.log(.firstOpen) }
        linkAnalytics()
    }

    /// Gives RevenueCat this install's Firebase ID for its Google Analytics link.
    /// nil (cleared) when analytics is off, so nothing is linked without consent.
    static func linkAnalytics() {
        PurchaseManager.shared.setFirebaseAppInstanceID(AppAnalytics.shared.appInstanceID)
    }
}
