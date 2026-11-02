import Foundation
import Observation
import ScanKit
import SlicePurchases
import SwiftData
import UIKit

/// App-wide state: the tab, the result card, batch mode and the toast.
@Observable
final class AppModel {
    enum Tab: Hashable { case scan, create, history, settings }

    struct ResultRoute: Identifiable {
        let id = UUID()
        let record: ScanRecord
        var fromHistory = false
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let icon: String
    }

    var tab: Tab = .scan
    var result: ResultRoute?
    var toast: Toast?
    var batchMode = false
    var batch: [ScanRecord] = []
    var showsBatchList = false

    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func show(_ text: String, icon: String = "checkmark.circle.fill") {
        toast = Toast(text: text, icon: icon)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// A code came off the camera or a photo: save it, then show it (or add it to the batch).
    func handle(_ code: ScannedCode, from source: ScanSource, context: ModelContext) {
        let record = ScanRecord(code: code, source: batchMode && source == .camera ? .batch : source)
        context.insert(record)
        try? context.save()
        ScanCounter.increment()
        Track.log(.scanSuccess, ["type": record.kindRaw, "format": code.format.rawValue, "source": record.sourceRaw])
        let presentation = ResultPresentation(payload: record.payload, raw: record.raw, format: record.format)
        if record.source == .batch {
            batch.append(record)
            show("Added to batch: \(presentation.title)", icon: "square.on.square")
            return
        }
        if UserDefaults.standard.bool(forKey: SettingsKey.autoOpen), PurchaseManager.shared.isPremium,
           case .url(let url) = record.payload, SafeLink.check(record.raw).isSafe {
            UIApplication.shared.open(url)
            Track.log(.resultAction, ["type": "open", "auto": true])
            show("Opened in Safari: \(presentation.title)", icon: "safari")
            return
        }
        result = ResultRoute(record: record)
    }

    /// The Batch chip: Pro only (`batch_scan`).
    func toggleBatch() {
        if batchMode {
            batchMode = false
            return
        }
        PaywallService.shared.gate(.batchScan) { [weak self] in
            self?.batchMode = true
            self?.show("Batch mode on. Scan codes one after another.", icon: "square.on.square")
        }
    }
}
