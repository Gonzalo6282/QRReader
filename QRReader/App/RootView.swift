import SlicePurchases
import SliceUI
import SwiftData
import SwiftUI

/// The four tabs from the mockup, the result card, the toast and the native paywall.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(SettingsKey.onboarded) private var onboarded = false

    var body: some View {
        if onboarded || (AppConfig.isUITesting && !AppConfig.arguments.contains("-showOnboarding")) {
            tabs
        } else {
            OnboardingFlow {
                onboarded = true
                Track.log(.onboardingComplete)
                // Soft paywall over the scanner, closable after 2.5 s.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    PaywallService.shared.gate(.onboardingEnd) {}
                }
            }
        }
    }

    private var tabs: some View {
        @Bindable var app = app
        return TabView(selection: tabSelection) {
            ScannerScreen()
                .toolbarBackground(.black, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(AppModel.Tab.scan)
            CreateScreen()
                .tabItem { Label("Create", systemImage: "qrcode") }
                .tag(AppModel.Tab.create)
            HistoryScreen()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppModel.Tab.history)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppModel.Tab.settings)
        }
        .tint(app.tab == .scan ? QodiTheme.lime : QodiTheme.limeInk)
        .sliceTheme(app.tab == .scan ? QodiTheme.brand : QodiTheme.main)
        .overlay(alignment: .top) {
            if let toast = app.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { app.toast = nil }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: app.toast)
        .sheet(item: $app.result) { route in
            ResultSheet(route: route)
                .sliceTheme(QodiTheme.main)
                .environment(app)
                .paywallHost()
        }
        .paywallHost(active: app.result == nil && !app.showsBatchList)
    }

    /// History is free for the first 3 scans, then `history_open`; closing the paywall keeps the current tab.
    private var tabSelection: Binding<AppModel.Tab> {
        Binding(
            get: { app.tab },
            set: { newTab in
                if newTab == .history, app.tab != .history, ScanCounter.historyNeedsPro, !PurchaseManager.shared.isPremium {
                    PaywallService.shared.gate(.historyOpen) { app.tab = .history }
                } else {
                    app.tab = newTab
                }
            })
    }
}

#Preview {
    RootView().environment(AppModel()).modelContainer(ModelStore.make(inMemory: true))
}
