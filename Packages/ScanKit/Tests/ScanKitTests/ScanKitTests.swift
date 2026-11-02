import Testing
@testable import ScanKit

struct ScanKitTests {
    @Test func hasAVersion() {
        #expect(ScanKit.version == "0.1.0")
    }
}
