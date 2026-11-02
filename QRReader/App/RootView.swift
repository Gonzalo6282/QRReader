import SwiftUI
import SliceUI

/// The four tabs from the mockup. Each screen is a placeholder until its milestone.
struct RootView: View {
    enum Tab: Hashable { case scan, create, history, settings }

    @State private var tab: Tab = .scan

    var body: some View {
        TabView(selection: $tab) {
            PlaceholderScreen(title: "Scan", note: "Camera scanner (M3)", dark: true)
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(Tab.scan)
            PlaceholderScreen(title: "Create", note: "Create QR codes (M5)")
                .tabItem { Label("Create", systemImage: "qrcode") }
                .tag(Tab.create)
            PlaceholderScreen(title: "History", note: "Scan history (M5)")
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)
            PlaceholderScreen(title: "Settings", note: "Settings (M6)")
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .sliceTheme(tab == .scan ? QodiTheme.brand : QodiTheme.main)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let note: String
    var dark = false
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

#Preview { RootView() }
