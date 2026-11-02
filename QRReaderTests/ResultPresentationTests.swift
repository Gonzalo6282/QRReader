import Foundation
import ScanKit
import Testing

@testable import QRReader

/// The result card's wording for each mockup sample.
struct ResultPresentationTests {
    private func present(_ raw: String, _ format: BarcodeFormat = .qr) -> ResultPresentation {
        ResultPresentation(payload: PayloadParser.parse(raw: raw, format: format), raw: raw, format: format)
    }

    @Test func safeLink() {
        let p = present("https://www.menu.lacantine-paris.fr/today?x=1")
        #expect(p.header == "Link")
        #expect(p.title == "menu.lacantine-paris.fr")
        #expect(p.subtitle == "/today?x=1")
        #expect(p.safety?.level == .ok)
        #expect(p.safety?.title == "Secure link, normal address")
        #expect(p.showsRaw)
        #expect(p.actions == [.open, .copyLink, .share])
    }

    @Test func suspiciousLink() {
        let p = present("http://paypa1-secure.co/login")
        #expect(p.safety?.level == .warn)
        #expect(p.safety?.title == "Looks like PayPal, but isn’t")
        #expect(p.safety?.detail == "paypa1-secure.co is not a PayPal address. Don’t enter a password here.")
    }

    @Test func wifi() {
        let p = present("WIFI:T:WPA;S:Home-5G;P:sunflower42;;")
        #expect(p.header == "Wi-Fi network")
        #expect(p.title == "Home-5G")
        #expect(p.fields == [.init(label: "Security", value: "WPA/WPA2"), .init(label: "Password", value: "••••••••••")])
        #expect(p.actions.first == .join)
    }

    @Test func contact() {
        let p = present("BEGIN:VCARD\nVERSION:3.0\nFN:Claire Moreau\nORG:Atelier Moreau\nTEL:+33 6 12 34 56 78\nEMAIL:claire@ateliermoreau.fr\nEND:VCARD")
        #expect(p.title == "Claire Moreau")
        #expect(p.fields.map(\.label) == ["Company", "Phone", "Email"])
        #expect(p.actions == [.contact, .call, .mail, .share])
    }

    @Test func productAndOtherBarcodes() {
        let product = present("5449000000996", .ean13)
        #expect(product.header == "EAN-13 barcode")
        #expect(product.note == "Product names and prices come in a later version. This code holds only the number.")
        #expect(product.actions.first == .search)
        let parcel = present("PKG-48213-UK", .code128)
        #expect(parcel.header == "Code 128 barcode")
        #expect(parcel.actions == [.copyText, .share])
    }

    @Test func otherTypes() {
        #expect(present("BEGIN:VEVENT\nSUMMARY:Design Week talk\nDTSTART:20261107T183000\nLOCATION:Somerset House\nEND:VEVENT").header == "Calendar event")
        #expect(present("geo:51.5007,-0.1246").title == "51.5007, -0.1246")
        #expect(present("tel:+442079460018").actions.first == .call)
        #expect(present("SMSTO:+447700900123:Table for 4 at 8pm?").fields == [.init(label: "Message", value: "Table for 4 at 8pm?")])
        #expect(present("mailto:bookings@thegreenroom.co.uk?subject=Reservation").actions.first == .writeEmail)
        #expect(present("Locker 214, door code 5521").header == "Text")
    }

    @Test func everyActionHasWords() {
        for action in ResultAction.allCases {
            #expect(!action.title.isEmpty && !action.icon.isEmpty && !action.analyticsName.isEmpty)
        }
    }

    @Test func eventTimeFormatting() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let text = ResultPresentation.when(EventTime(year: 2026, month: 11, day: 7, hour: 18, minute: 30), timeZone: london, locale: Locale(identifier: "en_GB"))
        #expect(text.contains("7") && text.contains("Nov") && text.contains("18:30"))
    }

    @Test func ago() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(Ago.text(now, now: now) == "Just now")
        #expect(Ago.text(now.addingTimeInterval(-300), now: now) == "5 min ago")
        #expect(Ago.text(now.addingTimeInterval(-3 * 3600), now: now) == "3 h ago")
    }
}

@MainActor
struct BatchExportTests {
    @Test func csvHasTheMockupColumns() {
        let record = ScanRecord(code: ScannedCode(raw: "https://a.b/?x=1,2", format: .qr), source: .batch)
        let csv = BatchExport.csv(for: [record])
        #expect(csv.hasPrefix("type,content,format,scanned_at\r\nurl,\"https://a.b/?x=1,2\",QR,"))
        #expect(BatchExport.file(for: []) == nil)
        #expect(BatchExport.file(for: [record]) != nil)
    }

    @Test func paywallContextLines() {
        #expect(QodiPaywall.context(for: .scanResultAction) == "Open, join, save and share with Pro")
        #expect(QodiPaywall.context(for: .onboardingEnd) == nil)
        #expect(Placement.onboardingEnd.isSoft && !Placement.batchScan.isSoft)
    }
}
