/// The symbologies Qodi reads (Build Doc, version 1.0 row 1).
public enum BarcodeFormat: String, CaseIterable, Codable, Sendable {
    case qr, ean13, ean8, upcA, upcE, code128, code39, dataMatrix, pdf417, aztec

    /// Name shown on the result card and in CSV exports, as in the mockup.
    public var displayName: String {
        switch self {
        case .qr: "QR"
        case .ean13: "EAN-13"
        case .ean8: "EAN-8"
        case .upcA: "UPC-A"
        case .upcE: "UPC-E"
        case .code128: "Code 128"
        case .code39: "Code 39"
        case .dataMatrix: "Data Matrix"
        case .pdf417: "PDF417"
        case .aztec: "Aztec"
        }
    }

    /// One-dimensional (bar) codes. Two-dimensional codes can hold links, Wi-Fi and contacts.
    public var isLinear: Bool {
        switch self {
        case .ean13, .ean8, .upcA, .upcE, .code128, .code39: true
        case .qr, .dataMatrix, .pdf417, .aztec: false
        }
    }

    /// Retail product numbers (GTIN): shown as "product" with the number and type.
    public var isProductCode: Bool {
        switch self {
        case .ean13, .ean8, .upcA, .upcE: true
        default: false
        }
    }

    /// Maps the names Apple's frameworks use, so the app needs no lookup table:
    /// Vision (`VNBarcodeSymbology.rawValue`, e.g. "VNBarcodeSymbologyQR") and
    /// AVFoundation (`AVMetadataObject.ObjectType.rawValue`, e.g. "org.iso.QRCode").
    public init?(systemName: String) {
        let key = systemName
            .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            .replacingOccurrences(of: "org.iso.", with: "")
            .replacingOccurrences(of: "org.gs1.", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        switch key {
        case "qr", "qrcode", "microqr": self = .qr
        case "ean13": self = .ean13
        case "ean8": self = .ean8
        case "upca": self = .upcA
        case "upce": self = .upcE
        case "code128", "gs1128": self = .code128
        case "code39", "code39checksum", "code39fullascii", "code39fullasciichecksum": self = .code39
        case "datamatrix": self = .dataMatrix
        case "pdf417", "micropdf417": self = .pdf417
        case "aztec": self = .aztec
        default: return nil
        }
    }
}

/// One code as it came off the camera or a photo.
public struct ScannedCode: Equatable, Hashable, Sendable {
    public let raw: String
    public let format: BarcodeFormat

    /// Apple's scanners report UPC-A as EAN-13 with a leading zero; this turns it back into
    /// the 12-digit UPC-A that is printed on the pack.
    public init(raw: String, format: BarcodeFormat) {
        if format == .ean13, raw.count == 13, raw.hasPrefix("0"), raw.allSatisfy(\.isASCIIDigit) {
            self.raw = String(raw.dropFirst())
            self.format = .upcA
        } else {
            self.raw = raw
            self.format = format
        }
    }
}

extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
