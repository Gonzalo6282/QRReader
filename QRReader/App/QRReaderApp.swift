import SwiftUI
import SliceUI

@main
struct QRReaderApp: App {
    init() {
        // Sheets, previews and UIKit-hosted views use this theme.
        SliceTheme.appDefault = QodiTheme.main
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
