import SlicePurchases
import SliceUI
import SwiftUI

/// The four tabs from the mockup, the result card, the toast and the native paywall.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: tabSelection) {
            ScannerScreen()
                .toolbarBackground(.black, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(AppModel.Tab.scan)
            PlaceholderScreen(title: "Create", note: "Create QR codes (M5)")
                .tabItem { Label("Create", systemImage: "qrcode") }
                .tag(AppModel.Tab.create)
            PlaceholderScreen(title: "History", note: "Scan history (M5)")
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppModel.Tab.history)
            PlaceholderScreen(title: "Settings", note: "Settings (M6)")
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

private struct PlaceholderScreen: View {
    let title: String
    let note: String
    @Environment(\.sliceTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Text(title).textStyle(.largeTitle)
            Text(note).textStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.canvas.ignoresSafeArea())
        .accessibilityIdentifier("screen-\(title)")
    }
}

#Preview {
    RootView().environment(AppModel()).modelContainer(ModelStore.make(inMemory: true))
}
