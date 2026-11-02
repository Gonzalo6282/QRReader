import Foundation

/// What a scanned code contains, ready for the result card.
public enum Payload: Equatable, Sendable {
    case url(URL)
    case wifi(WiFi)
    case contact(Contact)
    case event(CalendarEvent)
    case geo(Geo)
    case phone(String)
    case sms(SMS)
    case email(Email)
    case product(number: String, format: BarcodeFormat)
    case text(String)

    /// Stable name for history, analytics (`scan_success` type) and CSV.
    public var kind: PayloadKind {
        switch self {
        case .url: .url
        case .wifi: .wifi
        case .contact: .contact
        case .event: .event
        case .geo: .geo
        case .phone: .phone
        case .sms: .sms
        case .email: .email
        case .product: .product
        case .text: .text
        }
    }
}

public enum PayloadKind: String, CaseIterable, Codable, Sendable {
    case url, wifi, contact, event, geo, phone, sms, email, product, text
}

public enum WiFiSecurity: String, Codable, Sendable {
    case open, wep, wpa

    /// As on the result card: "None", "WEP", "WPA/WPA2".
    public var displayName: String {
        switch self {
        case .open: "None"
        case .wep: "WEP"
        case .wpa: "WPA/WPA2"
        }
    }
}

public struct WiFi: Equatable, Codable, Sendable {
    public var ssid: String
    public var password: String?
    public var security: WiFiSecurity
    public var hidden: Bool

    public init(ssid: String, password: String? = nil, security: WiFiSecurity = .wpa, hidden: Bool = false) {
        self.ssid = ssid
        self.password = password
        self.security = security
        self.hidden = hidden
    }
}

public struct Contact: Equatable, Codable, Sendable {
    public var fullName: String
    public var givenName: String?
    public var familyName: String?
    public var organization: String?
    public var title: String?
    public var phones: [String]
    public var emails: [String]
    public var urls: [String]
    public var address: String?
    public var note: String?

    public init(
        fullName: String = "", givenName: String? = nil, familyName: String? = nil, organization: String? = nil,
        title: String? = nil, phones: [String] = [], emails: [String] = [], urls: [String] = [],
        address: String? = nil, note: String? = nil
    ) {
        self.fullName = fullName
        self.givenName = givenName
        self.familyName = familyName
        self.organization = organization
        self.title = title
        self.phones = phones
        self.emails = emails
        self.urls = urls
        self.address = address
        self.note = note
    }
}

/// A date or date-time from an iCalendar code, kept as written so the app can turn it
/// into a `Date` in the right time zone.
public struct EventTime: Equatable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    /// nil for an all-day date (`DTSTART;VALUE=DATE:20261107`).
    public var hour: Int?
    public var minute: Int?
    public var second: Int?
    /// Written with a trailing `Z`.
    public var isUTC: Bool

    public init(year: Int, month: Int, day: Int, hour: Int? = nil, minute: Int? = nil, second: Int? = nil, isUTC: Bool = false) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.isUTC = isUTC
    }

    public var isAllDay: Bool { hour == nil }

    /// Floating times (no `Z`) are read in `timeZone`, the phone's own by default.
    public func date(in timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = isUTC ? .gmt : timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour ?? 0, minute: minute ?? 0, second: second ?? 0))
    }
}

public struct CalendarEvent: Equatable, Codable, Sendable {
    public var summary: String
    public var start: EventTime?
    public var end: EventTime?
    public var location: String?
    public var details: String?

    public init(summary: String, start: EventTime? = nil, end: EventTime? = nil, location: String? = nil, details: String? = nil) {
        self.summary = summary
        self.start = start
        self.end = end
        self.location = location
        self.details = details
    }
}

public struct Geo: Equatable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    /// The `q=` label some codes carry ("geo:0,0?q=Somerset+House").
    public var query: String?

    public init(latitude: Double, longitude: Double, query: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.query = query
    }
}

public struct SMS: Equatable, Codable, Sendable {
    public var number: String
    public var body: String?

    public init(number: String, body: String? = nil) {
        self.number = number
        self.body = body
    }
}

public struct Email: Equatable, Codable, Sendable {
    public var address: String
    public var subject: String?
    public var body: String?

    public init(address: String, subject: String? = nil, body: String? = nil) {
        self.address = address
        self.subject = subject
        self.body = body
    }
}
