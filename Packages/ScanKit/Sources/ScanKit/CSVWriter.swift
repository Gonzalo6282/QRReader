/// RFC 4180 CSV for the batch-scan export.
public enum CSVWriter {
    /// Rows joined with CRLF; fields with a comma, quote or line break are quoted, quotes doubled.
    public static func csv(_ rows: [[String]]) -> String {
        rows.map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + (rows.isEmpty ? "" : "\r\n")
    }

    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
