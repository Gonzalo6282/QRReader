import Foundation
import ScanKit
import SwiftData
import Testing

@testable import QRReader

@MainActor
struct CreatedCodesTests {
    private func count(_ context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<ScanRecord>())) ?? -1
    }

    @Test func savingAndSharingTheSameCodeKeepsOneEntry() throws {
        let container = ModelStore.make(inMemory: true)
        let context = container.mainContext
        let link = "https://instagram.com/lacantine.paris"
        #expect(CreatedCodes.save(payload: link, type: "social", colourHex: "#000000", logo: false, in: context))
        #expect(!CreatedCodes.save(payload: link, type: "social", colourHex: "#1d5c12", logo: true, in: context))
        #expect(count(context) == 1)
        let record = try #require(try context.fetch(FetchDescriptor<ScanRecord>()).first)
        #expect(record.colorHex == "#1d5c12" && record.hasLogo)
    }

    @Test func differentCodesAndScansStaySeparate() {
        let container = ModelStore.make(inMemory: true)
        let context = container.mainContext
        context.insert(ScanRecord(code: .init(raw: "https://a.b", format: .qr), source: .camera))
        CreatedCodes.save(payload: "https://a.b", type: "link", colourHex: "#000000", logo: false, in: context)
        CreatedCodes.save(payload: "https://c.d", type: "link", colourHex: "#000000", logo: false, in: context)
        #expect(count(context) == 3)
    }
}
