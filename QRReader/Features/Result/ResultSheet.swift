import Foundation
import Contacts
import ScanKit
import SliceUI
import SlicePurchases
import SwiftData
import SwiftUI

/// The result card (mockup `oResult`): what the code is, the safe-link check, and the Pro actions.
struct ResultSheet: View {
    let route: AppModel.ResultRoute

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sliceTheme) private var theme
    @State private var subSheet: SubSheet?
    @State private var confirmsDelete = false

    private var record: ScanRecord { route.record }
    private var presentation: ResultPresentation {
        ResultPresentation(payload: record.payload, raw: record.raw, format: record.format)
    }
    private var locked: Bool { !PurchaseManager.shared.isPremium }

    enum SubSheet: Identifiable {
        case share([Any])
        case contact(CNMutableContactBox)
        case event(CalendarEvent)

        var id: String {
            switch self {
            case .share: "share"
            case .contact: "contact"
            case .event: "event"
            }
        }
    }

    var body: some View {
        let p = presentation
        VStack(spacing: 0) {
            head(p)
            ScrollView {
                VStack(spacing: 12) {
                    if let s = p.safety { banner(s) }
                    if !p.fields.isEmpty { fields(p.fields) }
                    if let note = p.note { infoBanner(note) }
                    if p.showsRaw {
                        Text(record.raw)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(theme.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .textSelection(.enabled)
                    }
                    actions(p.actions)
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(QodiTheme.sheet.ignoresSafeArea())
        .presentationDetents([.fraction(0.66), .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $subSheet) { sheet in
            switch sheet {
            case .share(let items):
                ShareSheet(items: items) { completed, _ in if completed { Rating.happyMoment() } }
                    .presentationDetents([.medium, .large])
            case .contact(let box): NewContactSheet(contact: box.contact) { subSheet = nil; Rating.happyMoment() }
            case .event(let event): NewEventSheet(event: event) { subSheet = nil; Rating.happyMoment() }
            }
        }
        .alert("Delete this scan?", isPresented: $confirmsDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("It will be removed from your history on this iPhone. This can’t be undone.")
        }
    }

    // MARK: - Parts

    private func head(_ p: ResultPresentation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemName: p.icon, size: 44, lime: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.header).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.inkSecondary)
                Text(p.title).font(.system(size: 22, weight: .bold)).foregroundStyle(theme.ink)
                    .lineLimit(4).accessibilityIdentifier("resultTitle")
                if let sub = p.subtitle {
                    Text(sub).font(.system(size: 14)).foregroundStyle(theme.inkSecondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30).foregroundStyle(theme.inkSecondary)
                    .background(theme.surfaceAlt, in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 12)
    }

    private func banner(_ s: ResultPresentation.Safety) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: s.level == .ok ? "checkmark.shield" : "exclamationmark.triangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(s.level == .ok ? QodiTheme.limeInk : theme.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.system(size: 14, weight: .semibold))
                Text(s.detail).font(.system(size: 14))
            }
            .foregroundStyle(theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(s.level == .ok ? QodiTheme.okWash : QodiTheme.warnWash, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("safety")
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle").foregroundStyle(theme.inkSecondary)
            Text(text).font(.system(size: 14)).foregroundStyle(theme.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func fields(_ fields: [ResultPresentation.Field]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.offset) { index, f in
                if index > 0 { Divider().overlay(theme.line) }
                HStack(alignment: .top, spacing: 16) {
                    Text(f.label).foregroundStyle(theme.inkSecondary)
                    Spacer()
                    Text(f.value).foregroundStyle(theme.ink).multilineTextAlignment(.trailing).textSelection(.enabled)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func actions(_ actions: [ResultAction]) -> some View {
        VStack(spacing: 8) {
            if let primary = actions.first {
                Button { run(primary) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: primary.icon)
                        Text(primary.title)
                        if locked { Image(systemName: "lock.fill").font(.system(size: 13)).opacity(0.55) }
                    }
                }
                .buttonStyle(LimeButtonStyle())
                .accessibilityIdentifier("action-\(primary.rawValue)")
            }
            HStack(spacing: 8) {
                ForEach(actions.dropFirst(), id: \.self) { action in
                    Button { run(action) } label: {
                        VStack(spacing: 5) {
                            Image(systemName: action.icon).font(.system(size: 19))
                            Text(action.title).font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .foregroundStyle(theme.ink)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(theme.inkTertiary).padding(8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("action-\(action.rawValue)")
                }
            }
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                Button {
                    record.isFavourite.toggle()
                    try? context.save()
                    app.show(record.isFavourite ? "Added to favourites" : "Removed from favourites", icon: "star.fill")
                } label: {
                    Label(record.isFavourite ? "Favourite" : "Add to favourites", systemImage: record.isFavourite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(record.isFavourite ? QodiTheme.star : theme.inkSecondary)
                }
                .accessibilityIdentifier("favourite")
                if route.fromHistory {
                    Button { confirmsDelete = true } label: {
                        Label("Delete", systemImage: "trash").font(.system(size: 14)).foregroundStyle(theme.danger)
                    }
                }
            }
            Text(meta).font(.system(size: 12.5)).foregroundStyle(theme.inkTertiary).multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    private var meta: String {
        let how = switch record.source {
        case .photo: "From a photo"
        case .created: "Created by you"
        case .camera, .batch: "Scanned"
        }
        return "\(record.format.displayName) · \(how) \(Ago.text(record.date).lowercased()) · Saved on this iPhone"
    }

    // MARK: - Actions

    private func run(_ action: ResultAction) {
        let payload = record.payload
        let raw = record.raw
        PaywallService.shared.gate(.scanResultAction) {
            Task { @MainActor in
                switch await ResultActions.perform(action, payload: payload, raw: raw) {
                case .toast(let text, let icon):
                    app.show(text, icon: icon)
                    // Copy and a joined network are happy moments; a failed join isn't.
                    if !icon.contains("exclamationmark") { Rating.happyMoment() }
                case .share(let items): subSheet = .share(items)
                case .addContact(let contact): subSheet = .contact(CNMutableContactBox(contact: contact))
                case .addEvent(let event): subSheet = .event(event)
                case .nothing: break
                }
            }
        }
    }

    private func delete() {
        app.batch.removeAll { $0.id == record.id }
        context.delete(record)
        try? context.save()
        dismiss()
        app.show("Scan deleted", icon: "trash")
    }
}

/// Wraps the Contacts value so the sheet enum stays simple.
struct CNMutableContactBox {
    let contact: CNMutableContact
}

/// "Just now", "5 min ago", "3 h ago", or the date (mockup `ago`).
nonisolated enum Ago {
    static func text(_ date: Date, now: Date = .now) -> String {
        let minutes = Int((now.timeIntervalSince(date) / 60).rounded())
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = Int((Double(minutes) / 60).rounded())
        if hours < 24 { return "\(hours) h ago" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
