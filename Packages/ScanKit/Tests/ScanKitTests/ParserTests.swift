import Foundation
import Testing
@testable import ScanKit

/// Every sample code from the approved mockup, plus the variants real codes use.
struct ParserTests {
    // MARK: Links

    @Test func menuLink() throws {
        let p = PayloadParser.parse(raw: "https://menu.lacantine-paris.fr/today")
        #expect(p == .url(try #require(URL(string: "https://menu.lacantine-paris.fr/today"))))
        #expect(p.kind == .url)
    }

    @Test func linkIsTrimmedAndCaseInsensitive() throws {
        #expect(PayloadParser.parse(raw: "  HTTP://Example.com/a \n") == .url(try #require(URL(string: "HTTP://Example.com/a"))))
    }

    @Test func bareWwwBecomesHTTPS() throws {
        #expect(PayloadParser.parse(raw: "www.example.com/x") == .url(try #require(URL(string: "https://www.example.com/x"))))
        #expect(PayloadParser.parse(raw: "www.example .com") == .text("www.example .com"))
    }

    @Test func linkWithoutHostIsText() {
        #expect(PayloadParser.parse(raw: "https://") == .text("https://"))
    }

    // MARK: Barcodes

    @Test func productBarcodes() {
        #expect(PayloadParser.parse(raw: "5449000000996", format: .ean13) == .product(number: "5449000000996", format: .ean13))
        #expect(PayloadParser.parse(raw: "012345678905", format: .upcA) == .product(number: "012345678905", format: .upcA))
        #expect(PayloadParser.parse(raw: "96385074", format: .ean8).kind == .product)
        #expect(PayloadParser.parse(raw: "01234565", format: .upcE).kind == .product)
    }

    @Test func linearNonProductIsText() {
        #expect(PayloadParser.parse(raw: "PKG-48213-UK", format: .code128) == .text("PKG-48213-UK"))
        #expect(PayloadParser.parse(raw: "https://example.com", format: .code39) == .text("https://example.com"))
        #expect(PayloadParser.parse(raw: "12AB", format: .ean13) == .text("12AB"))
        #expect(PayloadParser.parse(raw: "1234567", format: .ean13) == .text("1234567"))
    }

    @Test func twoDimensionalFormatsParseLikeQR() {
        #expect(PayloadParser.parse(raw: "tel:+44123", format: .dataMatrix) == .phone("+44123"))
        #expect(PayloadParser.parse(raw: "tel:+44123", format: .aztec) == .phone("+44123"))
        #expect(PayloadParser.parse(raw: "tel:+44123", format: .pdf417) == .phone("+44123"))
    }

    @Test func parseScannedCode() {
        #expect(PayloadParser.parse(ScannedCode(raw: "0012345678905", format: .ean13)) == .product(number: "012345678905", format: .upcA))
    }

    // MARK: Wi-Fi

    @Test func wifi() {
        #expect(PayloadParser.parse(raw: "WIFI:T:WPA;S:Home-5G;P:sunflower42;;")
            == .wifi(WiFi(ssid: "Home-5G", password: "sunflower42", security: .wpa)))
    }

    @Test func wifiEscapesAnyOrderAndHidden() {
        #expect(PayloadParser.parse(raw: #"wifi:P:pa\;ss\:w\\d;S:My\,Net;T:WPA2;H:TRUE;;"#)
            == .wifi(WiFi(ssid: "My,Net", password: #"pa;ss:w\d"#, security: .wpa, hidden: true)))
    }

    @Test func wifiSecurityVariants() {
        #expect(PayloadParser.parse(raw: "WIFI:T:WEP;S:Old;P:abc;;") == .wifi(WiFi(ssid: "Old", password: "abc", security: .wep)))
        #expect(PayloadParser.parse(raw: "WIFI:T:nopass;S:Cafe;P:ignored;;") == .wifi(WiFi(ssid: "Cafe", password: nil, security: .open)))
        #expect(PayloadParser.parse(raw: "WIFI:S:Free;;") == .wifi(WiFi(ssid: "Free", security: .open)))
        #expect(PayloadParser.parse(raw: "WIFI:S:Home;P:pw;;") == .wifi(WiFi(ssid: "Home", password: "pw", security: .wpa)))
        #expect(PayloadParser.parse(raw: "WIFI:T:SAE;S:New;P:pw") == .wifi(WiFi(ssid: "New", password: "pw", security: .wpa)))
        #expect(PayloadParser.parse(raw: "WIFI:T:WPA;S:Home;P:;;") == .wifi(WiFi(ssid: "Home", password: nil, security: .wpa)))
    }

    @Test func wifiWithoutNetworkNameIsText() {
        #expect(PayloadParser.parse(raw: "WIFI:T:WPA;P:x;;").kind == .text)
        #expect(PayloadParser.parse(raw: "WIFI:S:;;").kind == .text)
    }

    @Test func securityDisplayNames() {
        #expect(WiFiSecurity.open.displayName == "None")
        #expect(WiFiSecurity.wep.displayName == "WEP")
        #expect(WiFiSecurity.wpa.displayName == "WPA/WPA2")
    }

    // MARK: Contacts

    @Test func vcardFromMockup() {
        let raw = "BEGIN:VCARD\nVERSION:3.0\nN:Moreau;Claire\nFN:Claire Moreau\nORG:Atelier Moreau\nTEL:+33 6 12 34 56 78\nEMAIL:claire@ateliermoreau.fr\nEND:VCARD"
        #expect(PayloadParser.parse(raw: raw) == .contact(Contact(
            fullName: "Claire Moreau", givenName: "Claire", familyName: "Moreau", organization: "Atelier Moreau",
            phones: ["+33 6 12 34 56 78"], emails: ["claire@ateliermoreau.fr"])))
    }

    @Test func vcardParamsGroupsFoldingAndEscapes() {
        let raw = "BEGIN:VCARD\r\nVERSION:3.0\r\nitem1.TEL;TYPE=CELL:+44 7700 900123\r\nTEL;TYPE=WORK:\r\n"
            + "EMAIL;TYPE=INTERNET:a@b.co\r\nURL:https://ex.com\r\nTITLE:Chef\r\nNOTE:Line one\\nline two\r\n"
            + "ADR;TYPE=WORK:;;1 High St;London;;N1 1AA;UK\r\nORG:Big\\, Co;Kitchen\r\nN:Doe;Jane;;;\r\n"
            + "FN:Jane\r\n  Doe\r\nX-CUSTOM:ignored\r\nno colon line\r\n:empty name\r\nEND:VCARD"
        guard case .contact(let c) = PayloadParser.parse(raw: raw) else { Issue.record("not a contact"); return }
        #expect(c.fullName == "Jane Doe")
        #expect(c.phones == ["+44 7700 900123"])
        #expect(c.emails == ["a@b.co"])
        #expect(c.urls == ["https://ex.com"])
        #expect(c.title == "Chef")
        #expect(c.note == "Line one\nline two")
        #expect(c.address == "1 High St, London, N1 1AA, UK")
        #expect(c.organization == "Big, Co, Kitchen")
        #expect(c.givenName == "Jane")
        #expect(c.familyName == "Doe")
    }

    @Test func vcardNameFallbacks() {
        guard case .contact(let a) = PayloadParser.parse(raw: "BEGIN:VCARD\nN:Doe;John\nEND:VCARD") else { Issue.record("a"); return }
        #expect(a.fullName == "John Doe")
        guard case .contact(let b) = PayloadParser.parse(raw: "BEGIN:VCARD\nORG:Acme\nEND:VCARD") else { Issue.record("b"); return }
        #expect(b.fullName == "Acme")
        guard case .contact(let c) = PayloadParser.parse(raw: "BEGIN:VCARD\nTEL:123\nEND:VCARD") else { Issue.record("c"); return }
        #expect(c.fullName == "")
        #expect(PayloadParser.parse(raw: "BEGIN:VCARD\nVERSION:3.0\nEND:VCARD").kind == .text)
    }

    @Test func mecard() {
        #expect(PayloadParser.parse(raw: "MECARD:N:Moreau,Claire;TEL:+331;TEL:;EMAIL:c@m.fr;URL:https://m.fr;ORG:Atelier;ADR:Paris;NOTE:Hi;NICKNAME:C;;")
            == .contact(Contact(fullName: "Claire Moreau", givenName: "Claire", familyName: "Moreau", organization: "Atelier",
                                phones: ["+331"], emails: ["c@m.fr"], urls: ["https://m.fr"], address: "Paris", note: "Hi")))
        guard case .contact(let only) = PayloadParser.parse(raw: "MECARD:N:Solo;;") else { Issue.record("solo"); return }
        #expect(only.fullName == "Solo")
        #expect(PayloadParser.parse(raw: "MECARD:EMAIL:;;").kind == .text)
    }

    // MARK: Calendar

    @Test func eventFromMockup() {
        let raw = "BEGIN:VEVENT\nSUMMARY:Design Week talk\nDTSTART:20261107T183000\nLOCATION:Somerset House, London\nEND:VEVENT"
        #expect(PayloadParser.parse(raw: raw) == .event(CalendarEvent(
            summary: "Design Week talk", start: EventTime(year: 2026, month: 11, day: 7, hour: 18, minute: 30, second: 0),
            location: "Somerset House, London")))
    }

    @Test func eventInsideCalendarWithEndAndDescription() {
        let raw = "BEGIN:VCALENDAR\nVERSION:2.0\nSUMMARY:not this\nBEGIN:VEVENT\nSUMMARY:Launch\\, party\n"
            + "DTSTART;VALUE=DATE:20261224\nDTEND:20261224T2300Z\nDESCRIPTION:Bring a friend\nUID:1\nEND:VEVENT\nEND:VCALENDAR"
        guard case .event(let e) = PayloadParser.parse(raw: raw) else { Issue.record("not an event"); return }
        #expect(e.summary == "Launch, party")
        #expect(e.start == EventTime(year: 2026, month: 12, day: 24))
        #expect(e.start?.isAllDay == true)
        #expect(e.end == EventTime(year: 2026, month: 12, day: 24, hour: 23, minute: 0, second: 0, isUTC: true))
        #expect(e.details == "Bring a friend")
    }

    @Test func eventWithoutSummaryOrStartIsText() {
        #expect(PayloadParser.parse(raw: "BEGIN:VEVENT\nLOCATION:Somewhere\nEND:VEVENT").kind == .text)
        guard case .event(let e) = PayloadParser.parse(raw: "BEGIN:VEVENT\nDTSTART:20260101\nEND:VEVENT") else { Issue.record("start only"); return }
        #expect(e.summary == "")
    }

    @Test func eventTimes() {
        #expect(PayloadParser.eventTime("20261107T1830") == EventTime(year: 2026, month: 11, day: 7, hour: 18, minute: 30, second: 0))
        #expect(PayloadParser.eventTime("20261107t183045z") == EventTime(year: 2026, month: 11, day: 7, hour: 18, minute: 30, second: 45, isUTC: true))
        #expect(PayloadParser.eventTime("2026110") == nil)
        #expect(PayloadParser.eventTime("20261307") == nil)
        #expect(PayloadParser.eventTime("20261100") == nil)
        #expect(PayloadParser.eventTime("20261107T18") == nil)
        #expect(PayloadParser.eventTime("20261107T2560") == nil)
        #expect(PayloadParser.eventTime("20261107T1899") == nil)
        #expect(PayloadParser.eventTime("2026AB07") == nil)
    }

    @Test func eventTimeDates() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let floating = try #require(EventTime(year: 2026, month: 7, day: 1, hour: 12, minute: 0).date(in: london))
        let utc = try #require(EventTime(year: 2026, month: 7, day: 1, hour: 11, minute: 0, isUTC: true).date(in: london))
        #expect(floating == utc)  // London is UTC+1 in July
        #expect(EventTime(year: 2026, month: 7, day: 1).date() != nil)
    }

    // MARK: Location, phone, SMS, email, text

    @Test func geoFromMockup() {
        #expect(PayloadParser.parse(raw: "geo:51.5007,-0.1246") == .geo(Geo(latitude: 51.5007, longitude: -0.1246)))
    }

    @Test func geoWithParamsAndQuery() {
        #expect(PayloadParser.parse(raw: "GEO:51.5,-0.12,35;u=10?q=Somerset+House%2C%20London")
            == .geo(Geo(latitude: 51.5, longitude: -0.12, query: "Somerset House, London")))
        #expect(PayloadParser.parse(raw: "geo:1,2?z=3") == .geo(Geo(latitude: 1, longitude: 2)))
    }

    @Test func badGeoIsText() {
        #expect(PayloadParser.parse(raw: "geo:91,0").kind == .text)
        #expect(PayloadParser.parse(raw: "geo:0,181").kind == .text)
        #expect(PayloadParser.parse(raw: "geo:abc,1").kind == .text)
        #expect(PayloadParser.parse(raw: "geo:1").kind == .text)
        #expect(PayloadParser.parse(raw: "geo:").kind == .text)
    }

    @Test func phone() {
        #expect(PayloadParser.parse(raw: "tel:+442079460018") == .phone("+442079460018"))
        #expect(PayloadParser.parse(raw: "TEL: ") == .text("TEL:"))
    }

    @Test func smsTo() {
        #expect(PayloadParser.parse(raw: "SMSTO:+447700900123:Table for 4 at 8pm?")
            == .sms(SMS(number: "+447700900123", body: "Table for 4 at 8pm?")))
        #expect(PayloadParser.parse(raw: "smsto:123:a:b") == .sms(SMS(number: "123", body: "a:b")))
        #expect(PayloadParser.parse(raw: "SMSTO:123") == .sms(SMS(number: "123")))
        #expect(PayloadParser.parse(raw: "SMSTO::hi").kind == .text)
    }

    @Test func smsURI() {
        #expect(PayloadParser.parse(raw: "sms:+447700900123?body=Hi%20there") == .sms(SMS(number: "+447700900123", body: "Hi there")))
        #expect(PayloadParser.parse(raw: "sms:123;body=Yo") == .sms(SMS(number: "123", body: "Yo")))
        #expect(PayloadParser.parse(raw: "sms:123") == .sms(SMS(number: "123")))
        #expect(PayloadParser.parse(raw: "sms:?body=x").kind == .text)
    }

    @Test func mailtoFromMockup() {
        #expect(PayloadParser.parse(raw: "mailto:bookings@thegreenroom.co.uk?subject=Reservation")
            == .email(Email(address: "bookings@thegreenroom.co.uk", subject: "Reservation")))
        #expect(PayloadParser.parse(raw: "mailto:a@b.com?Subject=1+1%3D2&body=Hello%0Aworld&cc=x&flag")
            == .email(Email(address: "a@b.com", subject: "1+1=2", body: "Hello\nworld")))
        #expect(PayloadParser.parse(raw: "mailto:a@b.com") == .email(Email(address: "a@b.com")))
        #expect(PayloadParser.parse(raw: "mailto:?subject=x").kind == .text)
    }

    @Test func matmsg() {
        #expect(PayloadParser.parse(raw: "MATMSG:TO:a@b.com;SUB:Hi;BODY:Text;;") == .email(Email(address: "a@b.com", subject: "Hi", body: "Text")))
        #expect(PayloadParser.parse(raw: "MATMSG:SUB:Hi;;").kind == .text)
    }

    @Test func plainText() {
        #expect(PayloadParser.parse(raw: "Locker 214, door code 5521") == .text("Locker 214, door code 5521"))
        #expect(PayloadParser.parse(raw: "itms-apps://apps.apple.com") == .text("itms-apps://apps.apple.com"))
    }

    @Test func everyKindHasAName() {
        let samples: [Payload] = [
            .url(URL(string: "https://a.b")!), .wifi(WiFi(ssid: "a")), .contact(Contact()), .event(CalendarEvent(summary: "")),
            .geo(Geo(latitude: 0, longitude: 0)), .phone("1"), .sms(SMS(number: "1")), .email(Email(address: "a")),
            .product(number: "1", format: .ean8), .text(""),
        ]
        #expect(samples.map(\.kind) == PayloadKind.allCases)
    }

    // MARK: Helpers

    @Test func fieldsHandleStrayInput() {
        let f = PayloadParser.fields("A:1;novalue;;B:x\\")
        #expect(f.map { $0.0 } == ["A", "NOVALUE", "B"])
        #expect(f.map { $0.1 } == ["1", "", "x"])
        #expect(PayloadParser.fields(#"K\:EY:v"#).first?.0 == "K:EY")
    }

    @Test func componentsKeepEscapes() {
        #expect(PayloadParser.components(#"a\;b;c\\;d\n"#) == ["a;b", #"c\"#, "d\n"])
    }
}
