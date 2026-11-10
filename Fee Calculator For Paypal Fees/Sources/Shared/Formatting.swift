//
//  Formatting.swift
//  Fee Calculator For Paypal Fees
//

import Foundation

enum Formatting {
    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.maximumFractionDigits
    }

    /// "1.234,56 €" in German, "€1,234.56" in English.
    static func currency(_ value: Double, code: String) -> String {
        value.formatted(.currency(code: code))
    }

    /// "2,49 %" or "2.49%" depending on the locale. `value` is a percentage, e.g. 2.49.
    static func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0...2)))
    }

    static func rateSummary(percent: Double, fixed: Double, currencyCode: String) -> String {
        guard fixed > 0 else { return Self.percent(percent) }
        return "\(Self.percent(percent)) + \(currency(fixed, code: currencyCode))"
    }

    /// A number for the input field, without grouping, e.g. "1234,5".
    static func plainNumber(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...fractionDigits)))
    }

    static func currencySymbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// Whether the locale writes the symbol before the amount ("$10" vs. "10 €").
    static func currencySymbolIsLeading(_ code: String) -> Bool {
        let sample = 1.0.formatted(.currency(code: code))
        return !(sample.first?.isNumber ?? true)
    }

    /// Common currencies for the custom profile, the user's own first.
    static var currencyCodes: [String] {
        let common = ["EUR", "USD", "GBP", "CHF", "CAD", "AUD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "JPY", "MXN", "BRL", "INR", "NZD", "SGD", "HKD", "ILS", "PHP", "THB", "TWD"]
        let own = Locale.current.currency?.identifier
        return ([own].compactMap(\.self) + common).reduce(into: []) { result, code in
            if !result.contains(code) { result.append(code) }
        }
    }
}
