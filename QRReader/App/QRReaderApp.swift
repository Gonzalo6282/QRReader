import SwiftData
import SwiftUI

@main
struct QRReaderApp: App {
    @State private var app = AppModel()
    private let container: ModelContainer

    init() {
        Bootstrap.start()
        container = ModelStore.make()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(container)
    }
}
