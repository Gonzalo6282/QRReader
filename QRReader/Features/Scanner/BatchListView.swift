import Foundation
import ScanKit
import SliceUI
import SwiftUI

/// Codes collected in batch mode, with CSV export (mockup `vBatch`).
struct BatchListView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sliceTheme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                if app.batch.isEmpty { empty } else { list }
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Batch list")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sliceTheme(QodiTheme.main)
    }

    private var list: some View {
        List {
            Section {
                ForEach(app.batch) { record in
                    let p = ResultPresentation(payload: record.payload, raw: record.raw, format: record.format)
                    HStack(spacing: 12) {
                        IconTile(systemName: p.icon)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).lineLimit(1)
                            Text("\(p.header) · \(record.format.displayName)").font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                        }
                    }
                }
            } header: {
                Text("\(app.batch.count) codes scanned in this batch")
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Clear list") { app.batch.removeAll() }.buttonStyle(PlainFillButtonStyle())
                if let file = BatchExport.file(for: app.batch) {
                    ShareLink(item: file) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                        .buttonStyle(LimeButtonStyle())
                }
            }
            .padding(16)
            .background(.bar)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            IconTile(systemName: "square.on.square", size: 64)
            Text("No codes in this batch").font(.system(size: 20, weight: .semibold)).padding(.top, 6)
            Text("Turn on Batch in the scanner and scan codes one after another. They collect here.")
                .multilineTextAlignment(.center).foregroundStyle(theme.inkSecondary)
            Button("Back to scanner") { dismiss() }.buttonStyle(LimeButtonStyle(height: 46)).frame(width: 220).padding(.top, 12)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The batch CSV: type, content, format, scanned_at (mockup `vBatch`).
enum BatchExport {
    static func csv(for records: [ScanRecord]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        let rows = records.map { [$0.kindRaw, $0.raw, $0.format.displayName, formatter.string(from: $0.date)] }
        return CSVWriter.csv([["type", "content", "format", "scanned_at"]] + rows)
    }

    static func file(for records: [ScanRecord]) -> URL? {
        guard !records.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Qodi batch.csv")
        do {
            try csv(for: records).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
