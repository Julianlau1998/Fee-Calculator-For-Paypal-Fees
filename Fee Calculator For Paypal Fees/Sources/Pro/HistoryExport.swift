//
//  HistoryExport.swift
//  Fee Calculator For Paypal Fees
//

import Foundation

/// Pro: the history as a CSV file that opens directly in Excel and Numbers.
struct HistoryExport {
    let csv: String

    init(entries: [SavedCalculation], locale: Locale = .current) {
        // Where the decimal separator is a comma, spreadsheets expect semicolons between columns.
        let usesDecimalComma = locale.decimalSeparator == ","
        let separator = usesDecimalComma ? ";" : ","

        func number(_ value: Double, _ code: String) -> String {
            let digits = Formatting.fractionDigits(for: code)
            let text = String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
            return usesDecimalComma ? text.replacingOccurrences(of: ".", with: ",") : text
        }

        func field(_ text: String) -> String {
            let needsQuotes = text.contains(separator) || text.contains("\"") || text.contains("\n")
            return needsQuotes ? "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : text
        }

        let header = [
            String(localized: "Date"),
            String(localized: "Name"),
            String(localized: "Mode"),
            String(localized: "Sent"),
            String(localized: "Fees"),
            String(localized: "Arrives"),
            String(localized: "Currency"),
            String(localized: "Rates")
        ]
        let dateFormat = Date.ISO8601FormatStyle(timeZone: .current).year().month().day().time(includingFractionalSeconds: false).dateTimeSeparator(.space)
        let rows = entries.map { entry in
            [
                entry.date.formatted(dateFormat),
                entry.title,
                String(localized: entry.mode.title),
                number(entry.gross, entry.currencyCode),
                number(entry.totalFees, entry.currencyCode),
                number(entry.net, entry.currencyCode),
                entry.currencyCode,
                entry.rateSummary
            ]
        }
        csv = ([header] + rows)
            .map { $0.map(field).joined(separator: separator) }
            .joined(separator: "\r\n")
    }

    /// Writes the CSV to a temporary file named like "PayPal Fees.csv" and returns its URL.
    func write() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: String(localized: "PayPal Fees") + ".csv")
        // A byte order mark makes Excel read umlauts and currency symbols as UTF-8.
        try Data(("\u{FEFF}" + csv).utf8).write(to: url, options: .atomic)
        return url
    }
}
