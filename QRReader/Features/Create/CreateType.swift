import ScanKit

/// The 8 Create types and their form fields (mockup `CTYPES`, `CFIELDS`).
nonisolated enum CreateType: String, CaseIterable, Identifiable, Sendable {
    case link, wifi, contact, text, email, phone, sms, social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .link: "Link"
        case .wifi: "Wi-Fi"
        case .contact: "Contact"
        case .text: "Text"
        case .email: "Email"
        case .phone: "Phone"
        case .sms: "Text message"
        case .social: "Social profile"
        }
    }

    var subtitle: String {
        switch self {
        case .link: "Website or menu"
        case .wifi: "Let guests join"
        case .contact: "Your business card"
        case .text: "Any note"
        case .email: "Pre-filled email"
        case .phone: "Tap to call"
        case .sms: "Pre-filled SMS"
        case .social: "Instagram, TikTok, X"
        }
    }

    var icon: String {
        switch self {
        case .link: "link"
        case .wifi: "wifi"
        case .contact: "person.crop.circle"
        case .text: "text.alignleft"
        case .email: "envelope"
        case .phone: "phone"
        case .sms: "message"
        case .social: "at"
        }
    }

    nonisolated struct Field: Identifiable, Sendable {
        let key: String
        let label: String
        let placeholder: String
        var keyboard: Keyboard = .text
        var id: String { key }
    }

    nonisolated enum Keyboard: Sendable { case text, url, email, phone, secret }

    var fields: [Field] {
        switch self {
        case .link: [Field(key: "url", label: "Website address", placeholder: "https://lacantine-paris.fr", keyboard: .url)]
        case .wifi: [Field(key: "ssid", label: "Network name", placeholder: "Home-5G"),
                     Field(key: "pw", label: "Password", placeholder: "sunflower42", keyboard: .secret)]
        case .contact: [Field(key: "name", label: "Full name", placeholder: "Claire Moreau"),
                        Field(key: "tel", label: "Phone", placeholder: "+33 6 12 34 56 78", keyboard: .phone),
                        Field(key: "email", label: "Email", placeholder: "claire@ateliermoreau.fr", keyboard: .email),
                        Field(key: "org", label: "Company", placeholder: "Atelier Moreau")]
        case .text: [Field(key: "text", label: "Text", placeholder: "Locker 214, door code 5521")]
        case .email: [Field(key: "to", label: "To", placeholder: "bookings@thegreenroom.co.uk", keyboard: .email),
                      Field(key: "subject", label: "Subject", placeholder: "Reservation")]
        case .phone: [Field(key: "tel", label: "Phone number", placeholder: "+44 20 7946 0018", keyboard: .phone)]
        case .sms: [Field(key: "tel", label: "Phone number", placeholder: "+44 7700 900123", keyboard: .phone),
                    Field(key: "body", label: "Message", placeholder: "Table for 4 at 8pm?")]
        case .social: [Field(key: "handle", label: "Username", placeholder: "lacantine.paris")]
        }
    }

    /// The text stored in the code, or nil while the form isn't filled in enough.
    func payload(_ f: [String: String], network: QRPayloadBuilder.SocialNetwork = .instagram) -> String? {
        func v(_ key: String) -> String { (f[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        switch self {
        case .link:
            return v("url").isEmpty ? nil : QRPayloadBuilder.link(v("url"))
        case .wifi:
            guard !v("ssid").isEmpty else { return nil }
            let pw = f["pw"] ?? ""
            return QRPayloadBuilder.wifi(WiFi(ssid: v("ssid"), password: pw.isEmpty ? nil : pw, security: pw.isEmpty ? .open : .wpa))
        case .contact:
            guard !v("name").isEmpty || !v("tel").isEmpty || !v("email").isEmpty else { return nil }
            let parts = v("name").split(separator: " ", maxSplits: 1).map(String.init)
            return QRPayloadBuilder.contact(Contact(
                fullName: v("name"), givenName: parts.first, familyName: parts.count > 1 ? parts[1] : nil,
                organization: v("org").isEmpty ? nil : v("org"),
                phones: v("tel").isEmpty ? [] : [v("tel")], emails: v("email").isEmpty ? [] : [v("email")]))
        case .text:
            return (f["text"] ?? "").isEmpty ? nil : QRPayloadBuilder.text(f["text"] ?? "")
        case .email:
            return v("to").isEmpty ? nil : QRPayloadBuilder.email(Email(address: v("to"), subject: v("subject").isEmpty ? nil : v("subject")))
        case .phone:
            return v("tel").isEmpty ? nil : QRPayloadBuilder.phone(v("tel"))
        case .sms:
            return v("tel").isEmpty ? nil : QRPayloadBuilder.sms(SMS(number: v("tel"), body: v("body").isEmpty ? nil : v("body")))
        case .social:
            return v("handle").isEmpty ? nil : QRPayloadBuilder.social(network, handle: v("handle"))
        }
    }
}

/// The 5 code colours (mockup swatches).
nonisolated enum CodeColour: String, CaseIterable, Identifiable, Sendable {
    case black = "#000000", forest = "#1d5c12", navy = "#0b2a5c", wine = "#7a1a3a", brown = "#5a3a00"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .black: "Black"
        case .forest: "Forest"
        case .navy: "Navy"
        case .wine: "Wine"
        case .brown: "Brown"
        }
    }
}
