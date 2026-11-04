import Foundation
import ScanKit
import SwiftData

/// Created codes in History: one entry per code. Saving or sharing the same code again
/// updates that entry (date, colour, logo) instead of adding another.
enum CreatedCodes {
    /// Returns true when a new entry was added.
    @discardableResult
    static func save(payload: String, type: String, colourHex: String, logo: Bool, in context: ModelContext, now: Date = .now) -> Bool {
        let created = ScanSource.created.rawValue
        let descriptor = FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.raw == payload && $0.sourceRaw == created })
        let existing = (try? context.fetch(descriptor))?.first
        let record = existing ?? ScanRecord(code: ScannedCode(raw: payload, format: .qr), source: .created)
        record.createdType = type
        record.colorHex = colourHex
        record.hasLogo = logo
        record.date = now
        if existing == nil { context.insert(record) }
        try? context.save()
        return existing == nil
    }
}
