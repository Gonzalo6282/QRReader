import Foundation

/// Turns the text inside a code into a `Payload` (Build Doc row 3, mockup `parse`).
/// Anything it can't recognise, or that is malformed, comes back as `.text`.
public enum PayloadParser {
    public static func parse(_ code: ScannedCode) -> Payload {
        parse(raw: code.raw, format: code.format)
    }

    public static func parse(raw: String, format: BarcodeFormat = .qr) -> Payload {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if format.isLinear {
            if format.isProductCode, (8...14).contains(text.count), text.allSatisfy(\.isASCIIDigit) {
                return .product(number: text, format: format)
            }
            return .text(text)
        }
        let lower = text.lowercased()
        let parsed: Payload?
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            parsed = url(text)
        } else if lower.hasPrefix("www."), !text.contains(" ") {
            parsed = url("https://" + text)
        } else if lower.hasPrefix("wifi:") {
            parsed = wifi(text.dropFirst(5))
        } else if lower.hasPrefix("begin:vcard") {
            parsed = vcard(text)
        } else if lower.hasPrefix("mecard:") {
            parsed = mecard(text.dropFirst(7))
        } else if lower.hasPrefix("begin:vevent") || lower.hasPrefix("begin:vcalendar") {
            parsed = event(text)
        } else if lower.hasPrefix("geo:") {
            parsed = geo(text.dropFirst(4))
        } else if lower.hasPrefix("tel:") {
            let number = text.dropFirst(4).trimmingCharacters(in: .whitespaces)
            parsed = number.isEmpty ? nil : .phone(number)
        } else if lower.hasPrefix("smsto:") {
            parsed = smsTo(text.dropFirst(6))
        } else if lower.hasPrefix("sms:") {
            parsed = smsURI(text.dropFirst(4))
        } else if lower.hasPrefix("mailto:") {
            parsed = mailto(text.dropFirst(7))
        } else if lower.hasPrefix("matmsg:") {
            parsed = matmsg(text.dropFirst(7))
        } else {
            parsed = nil
        }
        return parsed ?? .text(text)
    }

    // MARK: - Links

    static func url(_ string: String) -> Payload? {
        guard let url = URL(string: string), let host = url.host, !host.isEmpty else { return nil }
        return .url(url)
    }

    // MARK: - Wi-Fi (WIFI:T:WPA;S:name;P:pass;H:true;;)

    static func wifi(_ body: Substring) -> Payload? {
        let f = Dictionary(fields(body), uniquingKeysWith: { first, _ in first })
        guard let ssid = f["S"], !ssid.isEmpty else { return nil }
        let password = f["P"].flatMap(\.nonEmpty)
        let security: WiFiSecurity
        switch (f["T"] ?? "").uppercased() {
        case "WEP": security = .wep
        case "NOPASS": security = .open
        case "": security = password == nil ? .open : .wpa
        default: security = .wpa  // WPA, WPA2, WPA3, SAE
        }
        let hidden = (f["H"] ?? "").lowercased() == "true"
        return .wifi(WiFi(ssid: ssid, password: security == .open ? nil : password, security: security, hidden: hidden))
    }

    // MARK: - Contacts

    static func vcard(_ text: String) -> Payload? {
        var c = Contact()
        for line in lines(text) {
            switch line.name {
            case "FN": c.fullName = unescape(line.value).trimmed
            case "N":
                let parts = components(line.value)
                c.familyName = parts.first?.trimmed.nonEmpty
                c.givenName = parts.dropFirst().first?.trimmed.nonEmpty
            case "ORG": c.organization = components(line.value).map(\.trimmed).filter { !$0.isEmpty }.joined(separator: ", ").nonEmpty
            case "TITLE": c.title = unescape(line.value).trimmed.nonEmpty
            case "TEL": add(line.value, to: &c.phones)
            case "EMAIL": add(line.value, to: &c.emails)
            case "URL": add(line.value, to: &c.urls)
            case "ADR": c.address = components(line.value).map(\.trimmed).filter { !$0.isEmpty }.joined(separator: ", ").nonEmpty
            case "NOTE": c.note = unescape(line.value).trimmed.nonEmpty
            default: break
            }
        }
        return finish(c)
    }

    /// MECARD:N:Moreau,Claire;TEL:+33…;EMAIL:…;;
    static func mecard(_ body: Substring) -> Payload? {
        var c = Contact()
        for (key, value) in fields(body) {
            let v = value.trimmed
            switch key {
            case "N":
                let parts = v.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map { String($0).trimmed }
                c.familyName = parts.first?.nonEmpty
                c.givenName = parts.dropFirst().first?.nonEmpty
            case "TEL": if !v.isEmpty { c.phones.append(v) }
            case "EMAIL": if !v.isEmpty { c.emails.append(v) }
            case "URL": if !v.isEmpty { c.urls.append(v) }
            case "ORG": c.organization = v.nonEmpty
            case "ADR": c.address = v.nonEmpty
            case "NOTE": c.note = v.nonEmpty
            default: break
            }
        }
        return finish(c)
    }

    private static func add(_ value: String, to list: inout [String]) {
        let v = unescape(value).trimmed
        if !v.isEmpty { list.append(v) }
    }

    private static func finish(_ contact: Contact) -> Payload? {
        var c = contact
        if c.fullName.isEmpty {
            c.fullName = [c.givenName, c.familyName].compactMap { $0 }.joined(separator: " ")
        }
        if c.fullName.isEmpty { c.fullName = c.organization ?? "" }
        guard !c.fullName.isEmpty || !c.phones.isEmpty || !c.emails.isEmpty else { return nil }
        return .contact(c)
    }

    // MARK: - Calendar (BEGIN:VEVENT … END:VEVENT, alone or inside VCALENDAR)

    static func event(_ text: String) -> Payload? {
        var e = CalendarEvent(summary: "")
        var inEvent = false
        for line in lines(text) {
            let value = unescape(line.value).trimmed
            if line.name == "BEGIN" || line.name == "END" {
                if value.uppercased() == "VEVENT" { inEvent = line.name == "BEGIN" }
                continue
            }
            guard inEvent else { continue }
            switch line.name {
            case "SUMMARY": e.summary = value
            case "DTSTART": e.start = eventTime(value)
            case "DTEND": e.end = eventTime(value)
            case "LOCATION": e.location = value.nonEmpty
            case "DESCRIPTION": e.details = value.nonEmpty
            default: break
            }
        }
        guard !e.summary.isEmpty || e.start != nil else { return nil }
        return .event(e)
    }

    /// 20261107T183000, 20261107T183000Z, 20261107T1830 or 20261107 (all day).
    static func eventTime(_ value: String) -> EventTime? {
        var s = value
        var utc = false
        if s.uppercased().hasSuffix("Z") {
            utc = true
            s.removeLast()
        }
        let parts = s.uppercased().split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
        let d = parts[0]
        guard d.count == 8, d.allSatisfy(\.isASCIIDigit),
              let year = Int(d.prefix(4)), let month = Int(d.dropFirst(4).prefix(2)), let day = Int(d.suffix(2)),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        guard parts.count == 2 else { return EventTime(year: year, month: month, day: day, isUTC: utc) }
        let t = parts[1]
        guard t.count == 4 || t.count == 6, t.allSatisfy(\.isASCIIDigit),
              let hour = Int(t.prefix(2)), let minute = Int(t.dropFirst(2).prefix(2)),
              let second = t.count == 6 ? Int(t.suffix(2)) : 0,
              hour < 24, minute < 60
        else { return nil }
        return EventTime(year: year, month: month, day: day, hour: hour, minute: minute, second: second, isUTC: utc)
    }

    // MARK: - Location (geo:51.5007,-0.1246;u=35?q=Somerset+House)

    static func geo(_ body: Substring) -> Payload? {
        let halves = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let coords = halves[0].split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard coords.count >= 2, let lat = coords[0], let lon = coords[1],
              (-90...90).contains(lat), (-180...180).contains(lon)
        else { return nil }
        let q = halves.count == 2 ? query(halves[1], plusIsSpace: true)["q"]?.nonEmpty : nil
        return .geo(Geo(latitude: lat, longitude: lon, query: q))
    }

    // MARK: - SMS and email

    /// SMSTO:+447700900123:Table for 4 at 8pm?
    static func smsTo(_ body: Substring) -> Payload? {
        let parts = body.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let number = parts[0].trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return nil }
        return .sms(SMS(number: number, body: parts.count == 2 ? String(parts[1]).nonEmpty : nil))
    }

    /// sms:+447700900123?body=Hello (also `;body=`)
    static func smsURI(_ body: Substring) -> Payload? {
        let split = body.firstIndex { $0 == "?" || $0 == ";" }
        let number = String(split.map { body[..<$0] } ?? body).trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return nil }
        let params = split.map { query(body[body.index(after: $0)...], plusIsSpace: false) } ?? [:]
        return .sms(SMS(number: number, body: params["body"]?.nonEmpty))
    }

    /// mailto:bookings@example.com?subject=Reservation&body=…
    static func mailto(_ body: Substring) -> Payload? {
        let halves = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let address = decode(halves[0], plusIsSpace: false).trimmed
        guard !address.isEmpty else { return nil }
        let params = halves.count == 2 ? query(halves[1], plusIsSpace: false) : [:]
        return .email(Email(address: address, subject: params["subject"]?.nonEmpty, body: params["body"]?.nonEmpty))
    }

    /// MATMSG:TO:a@b.com;SUB:Hello;BODY:Text;;
    static func matmsg(_ body: Substring) -> Payload? {
        let f = Dictionary(fields(body), uniquingKeysWith: { first, _ in first })
        guard let to = f["TO"]?.trimmed, !to.isEmpty else { return nil }
        return .email(Email(address: to, subject: f["SUB"]?.nonEmpty, body: f["BODY"]?.nonEmpty))
    }

    // MARK: - Helpers

    /// `KEY:value;KEY:value;;` with `\` escaping (Wi-Fi, MECARD, MATMSG). Keys come back upper-cased.
    static func fields(_ body: Substring) -> [(String, String)] {
        var result: [(String, String)] = []
        var key = "", value = "", inKey = true, escaped = false
        for ch in body {
            if escaped {
                if inKey { key.append(ch) } else { value.append(ch) }
                escaped = false
                continue
            }
            switch ch {
            case "\\": escaped = true
            case ":" where inKey: inKey = false
            case ";":
                if !key.isEmpty { result.append((key.trimmed.uppercased(), value)) }
                key = ""
                value = ""
                inKey = true
            default:
                if inKey { key.append(ch) } else { value.append(ch) }
            }
        }
        if !key.isEmpty { result.append((key.trimmed.uppercased(), value)) }
        return result
    }

    struct Line {
        let name: String
        let value: String
    }

    /// vCard / iCalendar content lines, unfolded, with the group prefix and parameters removed.
    static func lines(_ text: String) -> [Line] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var unfolded: [String] = []
        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
            if raw.first == " " || raw.first == "\t", let last = unfolded.popLast() {
                unfolded.append(last + raw.dropFirst())
            } else {
                unfolded.append(String(raw))
            }
        }
        return unfolded.compactMap { line in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let head = line[..<colon].split(separator: ";").first.map(String.init) ?? ""
            let name = head.split(separator: ".").last.map { String($0).uppercased() } ?? ""
            guard !name.isEmpty else { return nil }
            return Line(name: name, value: String(line[line.index(after: colon)...]))
        }
    }

    /// vCard text escapes: `\n`, `\,`, `\;`, `\\`.
    static func unescape(_ s: String) -> String {
        var out = ""
        var escaped = false
        for ch in s {
            if escaped {
                out.append(ch == "n" || ch == "N" ? "\n" : ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// Splits a structured vCard value on unescaped `;` and unescapes each part.
    static func components(_ s: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false
        for ch in s {
            if escaped {
                current.append("\\")
                current.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == ";" {
                parts.append(unescape(current))
                current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(unescape(current))
        return parts
    }

    static func query(_ s: Substring, plusIsSpace: Bool) -> [String: String] {
        var out: [String: String] = [:]
        for pair in s.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = decode(kv[0], plusIsSpace: plusIsSpace).lowercased()
            if out[key] == nil { out[key] = kv.count == 2 ? decode(kv[1], plusIsSpace: plusIsSpace) : "" }
        }
        return out
    }

    static func decode(_ s: Substring, plusIsSpace: Bool) -> String {
        let text = plusIsSpace ? s.replacingOccurrences(of: "+", with: " ") : String(s)
        return text.removingPercentEncoding ?? text
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { isEmpty ? nil : self }
}
