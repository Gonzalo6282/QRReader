import Foundation
import SliceAnalytics
import SlicePurchases
import SliceUI
import SwiftUI

/// The Settings tab (mockup `vSettings`) on SliceUI's StandardSettings: the Pro card, the
/// scanning switches, then the library's Account, Help and Privacy sections.
struct SettingsScreen: View {
    @Environment(\.sliceTheme) private var theme
    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.vibration) private var vibration = true
    @AppStorage(SettingsKey.autoOpen) private var autoOpen = false

    static let identity = AppIdentity(
        name: "Qodi", company: "Slice of Life Ltd", appStoreID: "6829893719",
        supportEmail: AppConfig.supportEmail, privacyURL: AppConfig.privacyURL, termsURL: AppConfig.termsURL)

    var body: some View {
        NavigationStack {
            StandardSettings(
                app: Self.identity,
                purchases: SettingsPurchases(
                    isPremium: { PurchaseManager.shared.isPremium },
                    restore: { await PurchaseManager.shared.restore() },
                    upgrade: { PaywallService.shared.gate(.settingsUpgrade) {} },
                    premiumText: "Qodi Pro",
                    plansText: "Weekly \(AppConfig.weeklyPrice) with a 3-day free trial, or yearly \(AppConfig.yearlyPrice).",
                    billingText: "Payments are handled by Apple. Cancel in Settings › your name › Subscriptions; refunds at reportaproblem.apple.com. Deleting the app does not cancel the subscription. Codes you created keep working if you cancel.",
                    diagnostics: { await PurchaseManager.shared.diagnostics() }),
                analytics: AppAnalytics.shared.requiresConsent ? SettingsAnalytics(
                    isOn: { AppAnalytics.shared.isEnabled },
                    setOn: { on in
                        AppAnalytics.shared.setConsent(on)
                        Track.log(.consent, ["analytics": on])
                    }) : nil,
                help: SettingsHelp(faqs: Self.faqs, reportTopics: Self.reportTopics, reportFooter: "We answer within 2 working days."),
                share: SettingsShare(message: "I scan QR codes and barcodes with Qodi: https://apps.apple.com/app/id6829893719"),
                header: AnyView(ProCard()),
                debug: debugRows
            ) {
                scanning
            }
        }
    }

    private var scanning: some View {
        GroupedSection(header: "Scanning", footer: "Opens safe links straight away. Links that look suspicious always show the card first.") {
            Toggle(isOn: $sound) { label("Sound", icon: "speaker.wave.2") }
                .padding(.horizontal, 14).padding(.vertical, 8)
            RowDivider()
            Toggle(isOn: $vibration) { label("Vibration", icon: "iphone.radiowaves.left.and.right") }
                .padding(.horizontal, 14).padding(.vertical, 8)
            RowDivider()
            Toggle(isOn: Binding(get: { autoOpen }, set: { on in
                if on, !PurchaseManager.shared.isPremium {
                    PaywallService.shared.gate(.settingsUpgrade) { autoOpen = true }
                } else {
                    autoOpen = on
                }
            })) {
                HStack(spacing: 6) {
                    label("Open links automatically", icon: "arrow.up.forward.app")
                    if !PurchaseManager.shared.isPremium { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(theme.inkTertiary) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .tint(Color(hex: "#34c759"))
    }

    private func label(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon, tint: .neutral)
            Text(title).font(theme.font(.callout)).foregroundStyle(theme.ink)
        }
    }

    private var debugRows: AnyView? {
        #if DEBUG
        AnyView(GroupedSection(header: "Debug") {
            Button("Reset onboarding and scan count") {
                UserDefaults.standard.set(false, forKey: SettingsKey.onboarded)
                UserDefaults.standard.set(0, forKey: SettingsKey.scanCount)
            }
            .padding(14)
        })
        #else
        nil
        #endif
    }

    static let faqs: [SettingsHelp.FAQ] = [
        .init("Is scanning free?", "Yes. Scanning codes with the camera or from photos, and seeing what they contain, is free. Pro unlocks the actions: opening links, joining Wi-Fi, saving contacts, copying and sharing, batch scanning, the full history and saving your own codes."),
        .init("Do my codes stop working if I cancel?", "No. Codes you create hold your link or details directly, with no redirect through our servers, so they keep working forever."),
        .init("What does the link check do?", "Before you open a link, Qodi checks it on your iPhone: look-alike brand names, bare IP addresses, short links and pages without HTTPS. Nothing is sent anywhere. It helps you spot risky links but can't catch everything."),
        .init("Where are my scans stored?", "Only on this iPhone. Camera pictures are read on the device and never saved or sent."),
        .init("Why won't a code scan?", "Hold the iPhone steady about 15 cm away, turn on the torch in the dark, or use 2× for small codes. For a screenshot or photo, use the photo button at the top left of the scanner."),
        .init("How do I cancel?", "Open the Settings app, tap your name, then Subscriptions. Deleting Qodi does not cancel the subscription."),
    ]

    static let reportTopics = ["A code won’t scan", "Wi-Fi didn’t join", "Subscription or payment", "Something else"]
}

/// The card at the top of Settings (mockup `.pro-card`).
private struct ProCard: View {
    var body: some View {
        let pro = PurchaseManager.shared.isPremium
        Button {
            if !pro { PaywallService.shared.gate(.settingsUpgrade) {} }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 30, weight: .semibold)).foregroundStyle(QodiTheme.lime)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pro ? "Pro is active" : "Try Pro free for 3 days").font(.system(size: 16.5, weight: .bold)).foregroundStyle(.white)
                    Text(pro ? "Thanks for supporting Qodi. Manage or cancel under Subscription." : "Open links, join Wi-Fi, save your codes and scan in bulk.")
                        .font(.system(size: 13.5)).foregroundStyle(QodiTheme.brand.inkSecondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(light: "#000000", dark: "#2a3029"), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
        .accessibilityIdentifier("proCard")
    }
}
