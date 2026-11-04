import Foundation
import Photos
import ScanKit
import SliceUI
import SlicePurchases
import SwiftData
import SwiftUI
import UIKit

/// The Create tab (mockup `vCreate`): 8 types, then a form with a live preview.
struct CreateScreen: View {
    @Environment(\.sliceTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should your code do?").font(.system(size: 13)).foregroundStyle(theme.inkSecondary).padding(.horizontal, 16)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(CreateType.allCases) { type in
                            NavigationLink(value: type) {
                                VStack(alignment: .leading, spacing: 4) {
                                    IconTile(systemName: type.icon, lime: true).padding(.bottom, 6)
                                    Text(type.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.ink)
                                    Text(type.subtitle).font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                                .padding(14)
                                .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("create-\(type.rawValue)")
                        }
                    }
                    .padding(.horizontal, 16)
                    Text("Your codes hold your link or details directly. No redirects, and they keep working even if you cancel.")
                        .font(.system(size: 13)).foregroundStyle(theme.inkSecondary).padding(.horizontal, 32).padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Create")
            .navigationDestination(for: CreateType.self) { CreateFormView(type: $0) }
        }
    }
}

/// One Create type's form, live preview, colours, logo, Save and Share (Pro, `qr_create_save`).
struct CreateFormView: View {
    let type: CreateType

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.sliceTheme) private var theme
    @State private var values: [String: String] = [:]
    @State private var network: QRPayloadBuilder.SocialNetwork = .instagram
    @State private var colour: CodeColour = .black
    @State private var logo = false
    @State private var shareImage: ShareItem?

    struct ShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var payload: String? { type.payload(values, network: network) }
    private var locked: Bool { !PurchaseManager.shared.isPremium }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if type == .social {
                    Picker("Network", selection: $network) {
                        ForEach(QRPayloadBuilder.SocialNetwork.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                form
                preview
                HStack(spacing: 10) {
                    Button { save(share: true) } label: { lockedLabel("Share", icon: "square.and.arrow.up") }
                        .buttonStyle(PlainFillButtonStyle())
                    Button { save(share: false) } label: { lockedLabel("Save", icon: "photo") }
                        .buttonStyle(LimeButtonStyle())
                        .accessibilityIdentifier("createSave")
                }
            }
            .padding(16)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle(type.title)
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image]) { completed, _ in if completed { Rating.happyMoment() } }
                .presentationDetents([.medium, .large])
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            ForEach(Array(type.fields.enumerated()), id: \.element.id) { index, field in
                if index > 0 { Divider().overlay(theme.line).padding(.leading, 16) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(type == .social ? "\(network.displayName) username" : field.label)
                        .font(.system(size: 12.5)).foregroundStyle(theme.inkSecondary)
                    TextField(field.placeholder, text: binding(field.key))
                        .font(.system(size: 16))
                        .textInputAutocapitalization(field.keyboard == .text ? .sentences : .never)
                        .autocorrectionDisabled(field.keyboard != .text)
                        .keyboardType(keyboard(field.keyboard))
                        .accessibilityIdentifier("field-\(field.key)")
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var preview: some View {
        VStack(spacing: 14) {
            Group {
                if let payload, let image = QRRenderer.image(for: payload, colour: colour, logo: logo, side: 600) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                        .accessibilityLabel("QR code preview")
                } else {
                    Text("Fill in the details to see your code").font(.system(size: 13)).foregroundStyle(theme.inkTertiary)
                        .multilineTextAlignment(.center).padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.surfaceAlt)
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 10) {
                ForEach(CodeColour.allCases) { c in
                    Button { colour = c } label: {
                        Circle().fill(Color(hex: c.rawValue)).frame(width: 30, height: 30)
                            .overlay(Circle().stroke(theme.line, lineWidth: 2))
                            .padding(3)
                            .overlay(Circle().stroke(colour == c ? QodiTheme.limeInk : .clear, lineWidth: 2))
                    }
                    .accessibilityLabel(c.name)
                    .accessibilityAddTraits(colour == c ? .isSelected : [])
                }
            }
            Toggle("Add logo in the middle", isOn: $logo).tint(Color(hex: "#34c759"))
            Text("Static code: it works offline and never expires.").font(.system(size: 12.5)).foregroundStyle(theme.inkSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func lockedLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
            if locked { Image(systemName: "lock.fill").font(.system(size: 12)).opacity(0.55) }
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func keyboard(_ k: CreateType.Keyboard) -> UIKeyboardType {
        switch k {
        case .url: .URL
        case .email: .emailAddress
        case .phone: .phonePad
        case .text, .secret: .default
        }
    }

    // MARK: - Save and share

    private func save(share: Bool) {
        guard let payload, let image = QRRenderer.image(for: payload, colour: colour, logo: logo) else {
            app.show("Fill in the details first", icon: "exclamationmark.triangle.fill")
            return
        }
        PaywallService.shared.gate(.qrCreateSave) {
            record(payload)
            if share {
                shareImage = ShareItem(image: image)
            } else {
                Task { @MainActor in
                    let ok = await PhotoSaver.save(image)
                    if ok { Rating.happyMoment() }
                    app.show(ok ? "Saved to Photos" : "Couldn’t save. Allow Qodi to add photos in Settings.",
                             icon: ok ? "photo" : "exclamationmark.triangle.fill")
                }
            }
        }
    }

    private func record(_ payload: String) {
        let isNew = CreatedCodes.save(payload: payload, type: type.rawValue, colourHex: colour.rawValue, logo: logo, in: context)
        if isNew { Track.log(.qrCreated, ["type": type.rawValue, "logo": logo]) }
    }
}

/// Adds an image to the photo library (add-only permission).
nonisolated enum PhotoSaver {
    static func save(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }
}
