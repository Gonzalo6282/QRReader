import ScanKit
import SliceQR
import Testing

@testable import QRReader

struct AppSmokeTests {
    @Test func scanKitIsLinked() {
        #expect(!ScanKit.version.isEmpty)
    }

    @Test func sliceLibraryIsLinked() {
        #expect(SliceQR.image(for: "https://slice-of-life.uk") != nil)
    }
}
