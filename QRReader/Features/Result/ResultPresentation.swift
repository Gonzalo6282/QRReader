import Foundation
import ScanKit

/// What the result card shows for a payload: wording from the approved mockup (`parse` in index.html).
nonisolated struct ResultPresentation: Equatable, Sendable {
    nonisolated struct Field: Equatable, Hashable, Sendable {
        let label: String
        let value: String
    }

    nonisolated struct Safety: Equatable, Sendable {
        enum Level: Sendable { case ok, warn }
        let level: Level
        let title: String
        let detail: String
    }

    /// Small grey line above the title ("Link", "Wi-Fi network", "EAN-13 barcode").
    let header: String
    /// The big line (domain, network name, person, number).
    let title: String
    /// Under the title: a link's path.
    let subtitle: String?
    let icon: String
    let fields: [Field]
    let note: String?
    let safety: Safety?
    /// Links show the full address under the check.
    let showsRaw: Bool
    /// The first action is the big lime button.
    let actions: [ResultAction]

    init(payload: Payload, raw: String, format: BarcodeFormat) {
        var subtitle: String?
        var fields: [Field] = []
        var note: String?
        var safety: Safety?
        var showsRaw = false
        switch payload {
        case .product(let number, let format):
            header = "\(format.displayName) barcode"
            title = number
            icon = "barcode"
            fields = [Field(label: "Type", value: format.displayName), Field(label: "Number", value: number)]
            note = "Product names and prices come in a later version. This code holds only the number."
            actions = [.search, .copy, .share]
        case .text(let text) where format.isLinear:
            header = "\(format.displayName) barcode"
            title = text
            icon = "barcode"
            fields = [Field(label: "Type", value: format.displayName)]
            actions = [.copyText, .share]
        case .url(let url):
            header = "Link"
            let host = (url.host ?? raw).lowercased()
            title = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            let path = url.path + (url.query.map { "?" + $0 } ?? "")
            subtitle = path.isEmpty || path == "/" ? nil : path
            icon = "link"
            safety = Self.safety(for: SafeLink.check(raw))
            showsRaw = true
            actions = [.open, .copyLink, .share]
        case .wifi(let wifi):
            header = "Wi-Fi network"
            title = wifi.ssid
            icon = "wifi"
            let dots = wifi.password.map { String(repeating: "•", count: min($0.count, 10)) } ?? "None"
            fields = [Field(label: "Security", value: wifi.security.displayName), Field(label: "Password", value: dots)]
            actions = wifi.password == nil ? [.join, .share] : [.join, .copyPassword, .share]
        case .contact(let c):
            header = "Contact"
            title = c.fullName.isEmpty ? (c.phones.first ?? c.emails.first ?? "Contact") : c.fullName
            icon = "person.crop.circle"
            if let org = c.organization { fields.append(Field(label: "Company", value: org)) }
            if let title = c.title { fields.append(Field(label: "Job title", value: title)) }
            fields += c.phones.map { Field(label: "Phone", value: $0) }
            fields += c.emails.map { Field(label: "Email", value: $0) }
            fields += c.urls.map { Field(label: "Website", value: $0) }
            if let address = c.address { fields.append(Field(label: "Address", value: address)) }
            var acts: [ResultAction] = [.contact]
            if !c.phones.isEmpty { acts.append(.call) }
            if !c.emails.isEmpty { acts.append(.mail) }
            actions = acts + [.share]
        case .event(let e):
            header = "Calendar event"
            title = e.summary.isEmpty ? "Event" : e.summary
            icon = "calendar"
            if let start = e.start { fields.append(Field(label: "When", value: Self.when(start))) }
            if let location = e.location { fields.append(Field(label: "Where", value: location)) }
            actions = [.calendar, .copy, .share]
        case .geo(let g):
            header = "Location"
            title = g.query ?? String(format: "%.4f, %.4f", g.latitude, g.longitude)
            icon = "mappin.and.ellipse"
            fields = [Field(label: "Latitude", value: "\(g.latitude)"), Field(label: "Longitude", value: "\(g.longitude)")]
            actions = [.maps, .copy, .share]
        case .phone(let number):
            header = "Phone number"
            title = number
            icon = "phone"
            actions = [.call, .copyNumber, .share]
        case .sms(let sms):
            header = "Text message"
            title = sms.number
            icon = "message"
            if let body = sms.body { fields = [Field(label: "Message", value: body)] }
            actions = [.sms, .copy, .share]
        case .email(let email):
            header = "Email"
            title = email.address
            icon = "envelope"
            if let subject = email.subject { fields.append(Field(label: "Subject", value: subject)) }
            actions = [.writeEmail, .copyAddress, .share]
        case .text(let text):
            header = "Text"
            title = text
            icon = "text.alignleft"
            actions = [.copyText, .share]
        }
        self.subtitle = subtitle
        self.fields = fields
        self.note = note
        self.safety = safety
        self.showsRaw = showsRaw
    }

    static func safety(for result: SafeLink.Result) -> Safety {
        switch result {
        case .safe:
            Safety(level: .ok, title: "Secure link, normal address", detail: "Checked on this iPhone. Nothing was sent anywhere.")
        case .warning(.broken):
            Safety(level: .warn, title: "This link looks broken", detail: "It may not open.")
        case .warning(.lookalike(let brand, let host)):
            Safety(level: .warn, title: "Looks like \(brand), but isn’t",
                   detail: "\(host) is not a \(brand) address. Don’t enter a password here.")
        case .warning(.ipAddress):
            Safety(level: .warn, title: "Goes to a bare IP address",
                   detail: "Real companies rarely link to a number. Open only if you trust who gave you this code.")
        case .warning(.shortener):
            Safety(level: .warn, title: "Short link", detail: "The real destination is hidden until it opens.")
        case .warning(.insecure):
            Safety(level: .warn, title: "Not a secure link",
                   detail: "This page doesn’t use HTTPS, so others on the network could see what you send.")
        }
    }

    /// "Sat 7 Nov, 18:30", or "Sat 7 Nov" for all-day events.
    static func when(_ time: EventTime, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        guard let date = time.date(in: timeZone) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(time.isAllDay ? "EEEdMMM" : "EEEdMMMHHmm")
        return formatter.string(from: date)
    }
}

/// Buttons on the result card. Every one is a Pro action (`scan_result_action`).
nonisolated enum ResultAction: String, CaseIterable, Sendable {
    case open, copyLink, join, copyPassword, contact, call, mail, calendar, copy, maps, copyNumber
    case sms, writeEmail, copyAddress, copyText, search, share

    var title: String {
        switch self {
        case .open: "Open in Safari"
        case .copyLink: "Copy link"
        case .join: "Join network"
        case .copyPassword: "Copy password"
        case .contact: "Add to Contacts"
        case .call: "Call"
        case .mail: "Email"
        case .calendar: "Add to Calendar"
        case .copy: "Copy"
        case .maps: "Open in Maps"
        case .copyNumber: "Copy number"
        case .sms: "Send message"
        case .writeEmail: "Write email"
        case .copyAddress: "Copy address"
        case .copyText: "Copy text"
        case .search: "Search the web"
        case .share: "Share"
        }
    }

    var icon: String {
        switch self {
        case .open: "safari"
        case .copyLink, .copyPassword, .copy, .copyNumber, .copyAddress, .copyText: "doc.on.doc"
        case .join: "wifi"
        case .contact: "person.crop.circle.badge.plus"
        case .call: "phone"
        case .mail, .writeEmail: "envelope"
        case .calendar: "calendar.badge.plus"
        case .maps: "map"
        case .sms: "message"
        case .search: "magnifyingglass"
        case .share: "square.and.arrow.up"
        }
    }

    /// Analytics `result_action` type.
    var analyticsName: String {
        switch self {
        case .copyLink, .copyPassword, .copy, .copyNumber, .copyAddress, .copyText: "copy"
        case .writeEmail: "mail"
        default: rawValue
        }
    }
}
