import Foundation
import ScanKit
import SwiftData

/// Where a history entry came from (mockup: "from photo", "batch", "Created by you").
nonisolated enum ScanSource: String, Codable, Sendable {
    case camera, photo, batch, created
}

/// One scan or created code, saved only on this iPhone (Build Doc "Login and where data lives").
@Model
nonisolated final class ScanRecord {
    var id: UUID = UUID()
    var raw: String = ""
    var formatRaw: String = "qr"
    var kindRaw: String = "text"
    var date: Date = Date.now
    var isFavourite: Bool = false
    var sourceRaw: String = "camera"
    /// Created codes: which Create type, colour and logo.
    var createdType: String?
    var colorHex: String?
    var hasLogo: Bool = false

    init(code: ScannedCode, source: ScanSource, date: Date = .now) {
        raw = code.raw
        formatRaw = code.format.rawValue
        kindRaw = PayloadParser.parse(code).kind.rawValue
        sourceRaw = source.rawValue
        self.date = date
    }

    var format: BarcodeFormat { BarcodeFormat(rawValue: formatRaw) ?? .qr }
    var source: ScanSource { ScanSource(rawValue: sourceRaw) ?? .camera }
    var kind: PayloadKind { PayloadKind(rawValue: kindRaw) ?? .text }
    var payload: Payload { PayloadParser.parse(raw: raw, format: format) }
}

enum ModelStore {
    /// On disk normally; in memory for UI tests and previews.
    static func make(inMemory: Bool = AppConfig.isUITesting) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: ScanRecord.self, configurations: configuration)
        } catch {
            // A damaged store must not stop the scanner: fall back to memory.
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: ScanRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}
