import Foundation
import ScanKit
import SliceUI
import SwiftData
import SwiftUI

/// Store screenshots, taken by `ScreenshotTests` in the Simulator (which has no camera).
/// Launch with `-uiTesting -premium -screenshots -shot <scan|link|wifi|history|create>`.
enum ScreenshotMode {
    static var isOn: Bool { AppConfig.isUITesting && AppConfig.arguments.contains("-screenshots") }

    static var shot: String {
        let args = AppConfig.arguments
        guard let i = args.firstIndex(of: "-shot"), i + 1 < args.count else { return "scan" }
        return args[i + 1]
    }

    /// The code drawn on the card in front of the "camera".
    static let menuLink = "https://lacantine-paris.fr/menu"

    /// Fills History with a believable week of scans, then opens the screen being captured.
    @MainActor
    static func prepare(app: AppModel, context: ModelContext) {
        guard isOn else { return }
        let now = Date.now
        func add(_ raw: String, _ format: BarcodeFormat, _ source: ScanSource, minutesAgo: Double, favourite: Bool = false) -> ScanRecord {
            let record = ScanRecord(code: ScannedCode(raw: raw, format: format), source: source, date: now.addingTimeInterval(-minutesAgo * 60))
            record.isFavourite = favourite
            context.insert(record)
            return record
        }
        let link = add(menuLink, .qr, .camera, minutesAgo: 0.2)
        let wifi = add("WIFI:T:WPA;S:Cafe Lumen Guest;P:espresso2024;;", .qr, .camera, minutesAgo: 34, favourite: true)
        _ = add("5012345678900", .ean13, .camera, minutesAgo: 95)
        _ = add("BEGIN:VCARD\nVERSION:3.0\nN:Moreau;Claire\nFN:Claire Moreau\nORG:Atelier Moreau\nTEL:+44 20 7946 0958\nEMAIL:claire@ateliermoreau.co.uk\nEND:VCARD", .qr, .photo, minutesAgo: 60 * 5)
        _ = add("https://www.eventbrite.co.uk/e/design-week-tickets", .qr, .camera, minutesAgo: 60 * 26)
        _ = add("BEGIN:VEVENT\nSUMMARY:Design Week opening\nDTSTART:20261114T183000\nLOCATION:Shoreditch, London\nEND:VEVENT", .qr, .camera, minutesAgo: 60 * 27)
        _ = add("http://paypa1-secure-login.com/verify", .qr, .camera, minutesAgo: 60 * 50)
        let created = add("https://slice-of-life.uk", .qr, .created, minutesAgo: 60 * 72, favourite: true)
        created.createdType = "link"
        created.colorHex = CodeColour.forest.rawValue
        created.hasLogo = true
        try? context.save()

        switch shot {
        case "link": app.result = AppModel.ResultRoute(record: link)
        case "wifi": app.result = AppModel.ResultRoute(record: wifi)
        case "history": app.tab = .history
        case "create": app.tab = .create
        default: break
        }
    }
}

/// Stands in for the camera picture: a table with a printed menu card, the code inside the reticle.
struct ScreenshotScene: View {
    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.41)
            ZStack {
                LinearGradient(colors: [Color(hex: "#3a2a1e"), Color(hex: "#1c140e"), Color(hex: "#0d0907")],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(hex: "#f3d9a8").opacity(0.22), .clear], center: .init(x: 0.5, y: 0.38),
                               startRadius: 10, endRadius: geo.size.width * 0.9)
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#f6f1e7"))
                    .frame(width: 236, height: 290)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 4) {
                            Text("LA CANTINE").font(.system(size: 15, weight: .heavy, design: .serif)).tracking(2)
                            Text("Scan for our menu").font(.system(size: 11, weight: .medium)).opacity(0.7)
                        }
                        .foregroundStyle(Color(hex: "#2b2118"))
                        .padding(.bottom, 14)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
                    .rotationEffect(.degrees(-4))
                    .position(x: centre.x, y: centre.y + 30)
                if let image = QRRenderer.image(for: ScreenshotMode.menuLink, colour: .black, logo: false, side: 600) {
                    Image(uiImage: image).interpolation(.none).resizable()
                        .frame(width: 168, height: 168)
                        .rotationEffect(.degrees(-4))
                        .position(centre)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
