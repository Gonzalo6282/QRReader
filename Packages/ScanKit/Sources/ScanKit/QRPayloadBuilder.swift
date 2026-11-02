import Foundation

/// Builds the text stored in a created QR code (Build Doc row 7). Codes are static: they hold the
/// user's link or text directly, never a redirect, so they keep working forever.
public enum QRPayloadBuilder {
    public enum SocialNetwork: String, CaseIterable, Codable, Sendable {
        case instagram, tiktok, x

        public var displayName: String {
            switch self {
            case .instagram: "Instagram"
            case .tiktok: "TikTok"
            case .x: "X"
            }
        }
    }

    /// Adds `https://` when the user typed a bare address ("menu.example.com").
    public static func link(_ input: String) -> String {
        let s = input.trimmed
        guard !s.isEmpty else { return "" }
        return s.range(of: "^[A-Za-z][A-Za-z0-9+.-]*://", options: .regularExpression) == nil ? "https://" + s : s
    }

    public static func text(_ input: String) -> String { input }

    public static func wifi(_ wifi: WiFi) -> String {
        var s = "WIFI:T:" + (wifi.security == .open ? "nopass" : wifi.security == .wep ? "WEP" : "WPA")
        s += ";S:" + escapeField(wifi.ssid)
        if wifi.security != .open, let password = wifi.password, !password.isEmpty {
            s += ";P:" + escapeField(password)
        }
        if wifi.hidden { s += ";H:true" }
        return s + ";;"
    }

    /// vCard 3.0, which every phone's camera can add to Contacts.
    public static func contact(_ c: Contact) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        lines.append("N:" + escapeVCard(c.familyName ?? "") + ";" + escapeVCard(c.givenName ?? "") + ";;;")
        let full = c.fullName.isEmpty ? [c.givenName, c.familyName].compactMap { $0 }.joined(separator: " ") : c.fullName
        lines.append("FN:" + escapeVCard(full))
        if let org = c.organization, !org.isEmpty { lines.append("ORG:" + escapeVCard(org)) }
        if let title = c.title, !title.isEmpty { lines.append("TITLE:" + escapeVCard(title)) }
        lines += c.phones.filter { !$0.isEmpty }.map { "TEL:" + escapeVCard($0) }
        lines += c.emails.filter { !$0.isEmpty }.map { "EMAIL:" + escapeVCard($0) }
        lines += c.urls.filter { !$0.isEmpty }.map { "URL:" + escapeVCard($0) }
        if let note = c.note, !note.isEmpty { lines.append("NOTE:" + escapeVCard(note)) }
        lines.append("END:VCARD")
        return lines.joined(separator: "\n")
    }

    public static func email(_ e: Email) -> String {
        var params: [String] = []
        if let subject = e.subject, !subject.isEmpty { params.append("subject=" + percentEncode(subject)) }
        if let body = e.body, !body.isEmpty { params.append("body=" + percentEncode(body)) }
        return "mailto:" + e.address.trimmed + (params.isEmpty ? "" : "?" + params.joined(separator: "&"))
    }

    /// `tel:` keeps only digits and a leading `+`.
    public static func phone(_ number: String) -> String {
        "tel:" + dialable(number)
    }

    public static func sms(_ sms: SMS) -> String {
        "SMSTO:" + dialable(sms.number) + ":" + (sms.body ?? "")
    }

    /// A profile link from a handle ("@lacantine.paris") or a pasted profile link.
    public static func social(_ network: SocialNetwork, handle: String) -> String {
        let h = handle.trimmed
        if h.lowercased().hasPrefix("http://") || h.lowercased().hasPrefix("https://") { return h }
        let name = h.hasPrefix("@") ? String(h.dropFirst()) : h
        switch network {
        case .instagram: return "https://instagram.com/" + name
        case .tiktok: return "https://www.tiktok.com/@" + name
        case .x: return "https://x.com/" + name
        }
    }

    // MARK: - Escaping

    /// Wi-Fi and MECARD fields: backslash before `\ ; , : "`.
    static func escapeField(_ s: String) -> String {
        var out = ""
        for ch in s {
            if "\\;,:\"".contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// vCard text values: `\\`, `\,`, `\;` and `\n`.
    static func escapeVCard(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "\\", ",", ";": out += "\\" + String(ch)
            case "\n": out += "\\n"
            default: out.append(ch)
            }
        }
        return out
    }

    static func percentEncode(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func dialable(_ number: String) -> String {
        let t = number.trimmed
        let digits = t.filter(\.isASCIIDigit)
        return (t.hasPrefix("+") ? "+" : "") + digits
    }
}
