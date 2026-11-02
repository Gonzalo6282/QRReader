import Foundation

/// Fixed app facts (Build Doc "Company and accounts", decisions of 30 Oct).
enum AppConfig {
    static let productIDs = ["qr_pro_weekly", "qr_pro_yearly"]
    static let entitlement = "pro"
    static let supportEmail = "slice.of.life.ltd@gmail.com"
    static let supportSubject = "QR Reader support"
    static let termsURL = url("https://slice-of-life.uk/qr/terms")
    static let privacyURL = url("https://slice-of-life.uk/qr/privacy")
    static let supportURL = url("https://slice-of-life.uk/qr/support")
    static let weeklyPrice = "$9.99"
    static let yearlyPrice = "$59.99"
    /// History stays free for this many scans, then `history_open` (Build Doc paywall table).
    static let freeHistoryScans = 3

    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}

/// UserDefaults keys. Sound and vibration default to on.
enum SettingsKey {
    static let sound = "sound"
    static let vibration = "vibration"
    static let autoOpen = "autoOpenLinks"
    static let analytics = "analyticsEnabled"
    static let scanCount = "scanCount"
    static let onboarded = "onboardingDone"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [sound: true, vibration: true, autoOpen: false])
    }
}

/// Saved scans counted for the 3-scan history rule. Deleting scans doesn't lower it.
enum ScanCounter {
    static var count: Int { UserDefaults.standard.integer(forKey: SettingsKey.scanCount) }

    static func increment() {
        UserDefaults.standard.set(count + 1, forKey: SettingsKey.scanCount)
    }

    /// History is behind the paywall once the user has more than the free number of scans.
    static var historyNeedsPro: Bool { count > AppConfig.freeHistoryScans }
}
