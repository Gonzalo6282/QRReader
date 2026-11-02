import Foundation
import Testing
@testable import ScanKit

struct BarcodeFormatTests {
    @Test func displayNamesMatchTheMockup() {
        #expect(BarcodeFormat.allCases.map(\.displayName)
            == ["QR", "EAN-13", "EAN-8", "UPC-A", "UPC-E", "Code 128", "Code 39", "Data Matrix", "PDF417", "Aztec"])
    }

    @Test func groups() {
        #expect(BarcodeFormat.allCases.filter(\.isLinear) == [.ean13, .ean8, .upcA, .upcE, .code128, .code39])
        #expect(BarcodeFormat.allCases.filter(\.isProductCode) == [.ean13, .ean8, .upcA, .upcE])
    }

    @Test func visionNames() {
        let names = ["VNBarcodeSymbologyQR", "VNBarcodeSymbologyEAN13", "VNBarcodeSymbologyEAN8", "VNBarcodeSymbologyUPCE",
                     "VNBarcodeSymbologyCode128", "VNBarcodeSymbologyCode39", "VNBarcodeSymbologyDataMatrix",
                     "VNBarcodeSymbologyPDF417", "VNBarcodeSymbologyAztec", "VNBarcodeSymbologyMicroQR",
                     "VNBarcodeSymbologyMicroPDF417", "VNBarcodeSymbologyGS1DataBar", "VNBarcodeSymbologyCode39FullASCII"]
        #expect(names.map { BarcodeFormat(systemName: $0) }
            == [.qr, .ean13, .ean8, .upcE, .code128, .code39, .dataMatrix, .pdf417, .aztec, .qr, .pdf417, nil, .code39])
    }

    @Test func avFoundationNames() {
        let names = ["org.iso.QRCode", "org.gs1.EAN-13", "org.gs1.EAN-8", "org.gs1.UPC-E", "org.iso.Code128",
                     "org.iso.Code39", "org.iso.DataMatrix", "org.iso.PDF417", "org.iso.Aztec", "com.intermec.Code93",
                     "upca", "gs1128", "code39checksum", "code39fullasciichecksum"]
        #expect(names.map { BarcodeFormat(systemName: $0) }
            == [.qr, .ean13, .ean8, .upcE, .code128, .code39, .dataMatrix, .pdf417, .aztec, nil, .upcA, .code128, .code39, .code39])
    }

    @Test func upcAComesBackFromEAN13() {
        #expect(ScannedCode(raw: "0012345678905", format: .ean13) == ScannedCode(raw: "012345678905", format: .upcA))
        let ean = ScannedCode(raw: "5449000000996", format: .ean13)
        #expect(ean.format == .ean13)
        #expect(ean.raw == "5449000000996")
        #expect(ScannedCode(raw: "0ABCDEFGHIJKL", format: .ean13).format == .ean13)
        #expect(ScannedCode(raw: "012345", format: .ean13).format == .ean13)
        #expect(ScannedCode(raw: "0012345678905", format: .qr).format == .qr)
    }
}

struct SafeLinkTests {
    @Test func secureNormalLink() {
        #expect(SafeLink.check("https://menu.lacantine-paris.fr/today") == .safe)
        #expect(SafeLink.check("https://menu.lacantine-paris.fr/today").isSafe)
    }

    @Test func lookalikeBrands() {
        #expect(SafeLink.check("http://paypa1-secure.co/login") == .warning(.lookalike(brand: "PayPal", host: "paypa1-secure.co")))
        #expect(SafeLink.check("https://www.g00gle.com") == .warning(.lookalike(brand: "Google", host: "g00gle.com")))
        #expect(SafeLink.check("https://amaz0n.shop") == .warning(.lookalike(brand: "Amazon", host: "amaz0n.shop")))
        #expect(SafeLink.check("https://id.app1e.help") == .warning(.lookalike(brand: "Apple", host: "id.app1e.help")))
        #expect(SafeLink.check("https://MICROS0FT.net").isSafe == false)
    }

    @Test func bareIPAddresses() {
        #expect(SafeLink.check("https://192.168.0.1/admin") == .warning(.ipAddress))
        #expect(SafeLink.check("http://[2001:db8::1]/") == .warning(.ipAddress))
        #expect(SafeLink.check("https://300.1.1.1") == .safe)
        #expect(SafeLink.check("https://1.2.3") == .safe)
        #expect(SafeLink.check("https://1234.1.1.1") == .safe)
    }

    @Test func shorteners() {
        #expect(SafeLink.check("https://bit.ly/abc") == .warning(.shortener))
        #expect(SafeLink.check("https://www.tinyurl.com/abc") == .warning(.shortener))
    }

    @Test func plainHTTP() {
        #expect(SafeLink.check("http://example.com") == .warning(.insecure))
    }

    @Test func brokenLinks() {
        #expect(SafeLink.check("not a link") == .warning(.broken))
        #expect(SafeLink.check("ftp://example.com") == .warning(.broken))
        #expect(SafeLink.check("https://") == .warning(.broken))
    }
}

struct CSVWriterTests {
    @Test func escapesAsRFC4180() {
        let csv = CSVWriter.csv([["Type", "Content", "Date"], ["Link", "https://a.b/?x=1,2", "2 Nov"], ["Text", "He said \"hi\"\nthen left", ""]])
        #expect(csv == "Type,Content,Date\r\nLink,\"https://a.b/?x=1,2\",2 Nov\r\nText,\"He said \"\"hi\"\"\nthen left\",\r\n")
    }

    @Test func emptyAndCarriageReturn() {
        #expect(CSVWriter.csv([]) == "")
        #expect(CSVWriter.field("a\rb") == "\"a\rb\"")
    }
}

struct QRPayloadBuilderTests {
    @Test func links() {
        #expect(QRPayloadBuilder.link("  menu.example.com/today ") == "https://menu.example.com/today")
        #expect(QRPayloadBuilder.link("http://a.b") == "http://a.b")
        #expect(QRPayloadBuilder.link("") == "")
        #expect(QRPayloadBuilder.text("Locker 214") == "Locker 214")
    }

    @Test func wifiRoundTrip() {
        let networks = [
            WiFi(ssid: "Home-5G", password: "sunflower42"),
            WiFi(ssid: #"Café; "Guest", 2:\"#, password: #"p;a,s:s\"#, security: .wep, hidden: true),
            WiFi(ssid: "Open", security: .open),
        ]
        for w in networks {
            #expect(PayloadParser.parse(raw: QRPayloadBuilder.wifi(w)) == .wifi(w))
        }
        #expect(QRPayloadBuilder.wifi(WiFi(ssid: "Home-5G", password: "sunflower42")) == "WIFI:T:WPA;S:Home-5G;P:sunflower42;;")
        #expect(QRPayloadBuilder.wifi(WiFi(ssid: "Open", password: "x", security: .open)) == "WIFI:T:nopass;S:Open;;")
    }

    @Test func contactRoundTrip() {
        let c = Contact(fullName: "Claire Moreau", givenName: "Claire", familyName: "Moreau", organization: "Atelier, Moreau; Co",
                        title: "Owner", phones: ["+33 6 12 34 56 78", ""], emails: ["claire@ateliermoreau.fr"],
                        urls: ["https://ateliermoreau.fr"], note: "Line\\one\ntwo")
        var expected = c
        expected.phones = ["+33 6 12 34 56 78"]
        #expect(PayloadParser.parse(raw: QRPayloadBuilder.contact(c)) == .contact(expected))
    }

    @Test func contactWithoutFullName() {
        let built = QRPayloadBuilder.contact(Contact(givenName: "Jane", familyName: "Doe"))
        #expect(built == "BEGIN:VCARD\nVERSION:3.0\nN:Doe;Jane;;;\nFN:Jane Doe\nEND:VCARD")
    }

    @Test func emailRoundTrip() {
        let e = Email(address: "bookings@thegreenroom.co.uk", subject: "Table & drinks = 1+1?", body: "Hi #4\nThanks")
        #expect(PayloadParser.parse(raw: QRPayloadBuilder.email(e)) == .email(e))
        #expect(QRPayloadBuilder.email(Email(address: " a@b.com ")) == "mailto:a@b.com")
    }

    @Test func phoneAndSMS() {
        #expect(QRPayloadBuilder.phone("+44 20 7946 0018") == "tel:+442079460018")
        #expect(QRPayloadBuilder.phone("020 7946") == "tel:0207946")
        #expect(QRPayloadBuilder.sms(SMS(number: "+44 7700 900123", body: "Table for 4?")) == "SMSTO:+447700900123:Table for 4?")
        #expect(PayloadParser.parse(raw: QRPayloadBuilder.sms(SMS(number: "123"))) == .sms(SMS(number: "123")))
    }

    @Test func social() {
        #expect(QRPayloadBuilder.social(.instagram, handle: "@lacantine.paris") == "https://instagram.com/lacantine.paris")
        #expect(QRPayloadBuilder.social(.tiktok, handle: "lacantine") == "https://www.tiktok.com/@lacantine")
        #expect(QRPayloadBuilder.social(.x, handle: " @qodi ") == "https://x.com/qodi")
        #expect(QRPayloadBuilder.social(.x, handle: "https://x.com/qodi") == "https://x.com/qodi")
        #expect(QRPayloadBuilder.SocialNetwork.allCases.map(\.displayName) == ["Instagram", "TikTok", "X"])
        #expect(PayloadParser.parse(raw: QRPayloadBuilder.social(.instagram, handle: "a")).kind == .url)
    }
}
