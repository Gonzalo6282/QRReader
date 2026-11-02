import ScanKit
import SliceUI
import SwiftData
import SwiftUI

/// The History tab (mockup `vHistory`): search, Scanned / Favourites / Created, newest first.
struct HistoryScreen: View {
    enum Filter: String, CaseIterable, Identifiable {
        case scanned = "Scanned", favourites = "Favourites", created = "Created"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var app
    @Environment(\.sliceTheme) private var theme
    @Query(sort: \ScanRecord.date, order: .reverse) private var records: [ScanRecord]
    @State private var query = ""
    @State private var filter: Filter = .scanned

    private var shown: [ScanRecord] {
        records
            .filter { r in
                switch filter {
                case .scanned: r.source != .created
                case .favourites: r.isFavourite
                case .created: r.source == .created
                }
            }
            .filter { r in
                guard !query.isEmpty else { return true }
                let p = ResultPresentation(payload: r.payload, raw: r.raw, format: r.format)
                return "\(p.title) \(r.raw) \(p.header)".localizedCaseInsensitiveContains(query)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    content
                }
                .padding(.bottom, 24)
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("History")
            .searchable(text: $query, prompt: "Search scans")
        }
    }

    @ViewBuilder private var content: some View {
        if records.isEmpty {
            EmptyState(icon: "clock.arrow.circlepath", title: "No scans yet",
                       text: "Codes you scan or create show up here. They’re saved only on this iPhone.",
                       button: "Scan a code") { app.tab = .scan }
        } else if shown.isEmpty {
            EmptyState(
                icon: nil,
                title: !query.isEmpty ? "No matches" : filter == .favourites ? "No favourites yet" : "Nothing created yet",
                text: !query.isEmpty ? "Nothing in your history contains “\(query)”."
                    : filter == .favourites ? "Tap the star on any scan to keep it here." : "QR codes you make in Create are kept here.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { Divider().overlay(theme.line).padding(.leading, 58) }
                    row(record)
                }
            }
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func row(_ record: ScanRecord) -> some View {
        let p = ResultPresentation(payload: record.payload, raw: record.raw, format: record.format)
        let extra = switch record.source {
        case .photo: " · from photo"
        case .batch: " · batch"
        default: ""
        }
        return Button { app.result = AppModel.ResultRoute(record: record, fromHistory: true) } label: {
            HStack(spacing: 12) {
                IconTile(systemName: p.icon)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.title).font(.system(size: 16)).foregroundStyle(theme.ink).lineLimit(1)
                    Text("\(p.header) · \(Ago.text(record.date))\(extra)").font(.system(size: 13)).foregroundStyle(theme.inkSecondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                if record.isFavourite { Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(QodiTheme.star) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.inkTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Empty states (mockup `.empty`).
struct EmptyState: View {
    let icon: String?
    let title: String
    let text: String
    var button: String?
    var action: () -> Void = {}
    @Environment(\.sliceTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            if let icon { IconTile(systemName: icon, size: 64).padding(.bottom, 6) }
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(theme.ink)
            Text(text).font(.system(size: 15)).foregroundStyle(theme.inkSecondary).multilineTextAlignment(.center)
            if let button {
                Button(button, action: action).buttonStyle(LimeButtonStyle(height: 46)).frame(width: 200).padding(.top, 12)
            }
        }
        .padding(.horizontal, 36).padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}
