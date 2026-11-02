import Foundation

/// The on-device link check shown on every link result (Build Doc: "safe-link check runs on the
/// phone, with no server"). Rules and order come from the approved mockup.
public enum SafeLink {
    public enum Result: Equatable, Sendable {
        /// "Secure link, normal address"
        case safe
        case warning(Warning)

        public var isSafe: Bool { self == .safe }
    }

    public enum Warning: Equatable, Sendable {
        /// "This link looks broken"
        case broken
        /// "Looks like PayPal, but isn't"
        case lookalike(brand: String, host: String)
        /// "Goes to a bare IP address"
        case ipAddress
        /// "Short link"
        case shortener
        /// "Not a secure link"
        case insecure
    }

    /// Misspellings that imitate a brand, and the brand they imitate.
    static let lookalikes: [(fragment: String, brand: String)] = [
        ("paypa1", "PayPal"), ("g00gle", "Google"), ("amaz0n", "Amazon"), ("app1e", "Apple"), ("micros0ft", "Microsoft"),
    ]

    static let shorteners: Set<String> = ["bit.ly", "tinyurl.com", "t.co", "goo.gl"]

    public static func check(_ link: String) -> Result {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let rawHost = url.host?.lowercased(), !rawHost.isEmpty
        else { return .warning(.broken) }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        if let match = lookalikes.first(where: { host.contains($0.fragment) }) {
            return .warning(.lookalike(brand: match.brand, host: host))
        }
        if isIPAddress(host) { return .warning(.ipAddress) }
        if shorteners.contains(host) { return .warning(.shortener) }
        if scheme != "https" { return .warning(.insecure) }
        return .safe
    }

    /// IPv4 dotted quad, or any IPv6 literal (hosts never contain ":" otherwise).
    static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            part.allSatisfy(\.isASCIIDigit) && UInt8(part) != nil
        }
    }
}
