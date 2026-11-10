//
//  FeeRegion.swift
//  Fee Calculator For Paypal Fees
//

import Foundation

/// The rates PayPal charges a seller for receiving a payment for goods and services.
nonisolated struct FeeRates: Codable, Hashable {
    /// Percentage of the received amount, e.g. `2.49` for 2.49 %.
    var percent: Double
    /// Fixed fee per transaction in `currencyCode`.
    var fixed: Double
    var currencyCode: String
    /// Spread above the base exchange rate when a payment in another currency is converted.
    var conversionSpread: Double = 3
    /// Tax charged on top of the fee, e.g. 16 % VAT in Mexico.
    var feeTax: Double = 0
    /// Extra percentage for international payments. Only used by the custom profile;
    /// the presets define their own tiers in `FeeRegion.origins`.
    var internationalSurcharge: Double = 1.99
}

/// Where the payment comes from. Cross-border payments cost an extra percentage.
nonisolated struct SenderOrigin: Identifiable {
    let id: String
    let name: LocalizedStringResource
    /// Added to the base percentage, in percentage points.
    let surcharge: Double

    static func domestic(_ name: LocalizedStringResource = "Domestic") -> SenderOrigin {
        SenderOrigin(id: "domestic", name: name, surcharge: 0)
    }
}

/// PayPal fee presets per market.
///
/// Source: PayPal's official merchant fee schedules (paypalobjects.com), 2025–2026.
/// The rates are those for receiving payments for goods and services.
nonisolated enum FeeRegion: String, CaseIterable, Identifiable, Codable {
    case germany, austria, france, italy, spain, netherlands, otherEEA
    case sweden, norway, switzerland, unitedKingdom
    case unitedStates, canada, australia, mexico, india
    case custom

    var id: Self { self }

    /// ISO region code, used for the flag and the localized country name.
    var regionCode: String? {
        switch self {
        case .germany: "DE"
        case .austria: "AT"
        case .france: "FR"
        case .italy: "IT"
        case .spain: "ES"
        case .netherlands: "NL"
        case .sweden: "SE"
        case .norway: "NO"
        case .switzerland: "CH"
        case .unitedKingdom: "GB"
        case .unitedStates: "US"
        case .canada: "CA"
        case .australia: "AU"
        case .mexico: "MX"
        case .india: "IN"
        case .otherEEA, .custom: nil
        }
    }

    var name: String {
        switch self {
        case .otherEEA: String(localized: "Other EEA Countries")
        case .custom: String(localized: "Custom Rates")
        default: regionCode.flatMap { Locale.current.localizedString(forRegionCode: $0) } ?? rawValue
        }
    }

    var flag: String {
        switch self {
        case .otherEEA: "🇪🇺"
        case .custom: "✏️"
        default: regionCode.map(Self.flagEmoji) ?? ""
        }
    }

    /// Preset rates; `nil` for the custom profile, whose rates the user enters.
    var rates: FeeRates? {
        switch self {
        case .germany: FeeRates(percent: 2.49, fixed: 0.35, currencyCode: "EUR")
        case .austria: FeeRates(percent: 3.4, fixed: 0.35, currencyCode: "EUR")
        case .france: FeeRates(percent: 2.9, fixed: 0.35, currencyCode: "EUR")
        case .italy: FeeRates(percent: 3.4, fixed: 0.35, currencyCode: "EUR")
        case .spain: FeeRates(percent: 2.9, fixed: 0.35, currencyCode: "EUR")
        case .netherlands: FeeRates(percent: 3.4, fixed: 0.35, currencyCode: "EUR")
        case .otherEEA: FeeRates(percent: 3.4, fixed: 0.35, currencyCode: "EUR")
        case .sweden: FeeRates(percent: 3.4, fixed: 3.25, currencyCode: "SEK")
        case .norway: FeeRates(percent: 3.4, fixed: 2.8, currencyCode: "NOK")
        case .switzerland: FeeRates(percent: 3.4, fixed: 0.55, currencyCode: "CHF")
        case .unitedKingdom: FeeRates(percent: 2.9, fixed: 0.3, currencyCode: "GBP")
        case .unitedStates: FeeRates(percent: 2.99, fixed: 0, currencyCode: "USD", conversionSpread: 4)
        case .canada: FeeRates(percent: 2.9, fixed: 0.3, currencyCode: "CAD")
        case .australia: FeeRates(percent: 2.9, fixed: 0.3, currencyCode: "AUD", conversionSpread: 4)
        case .mexico: FeeRates(percent: 3.95, fixed: 4, currencyCode: "MXN", conversionSpread: 3.5, feeTax: 16)
        case .india: FeeRates(percent: 4.4, fixed: 0.3, currencyCode: "USD")
        case .custom: nil
        }
    }

    /// Sender locations with their cross-border surcharge. The first entry is always the cheapest.
    func origins(customSurcharge: Double) -> [SenderOrigin] {
        switch self {
        case .germany:
            [
                .domestic("Germany & EEA"),
                SenderOrigin(id: "uk", name: "United Kingdom", surcharge: 1.29),
                SenderOrigin(id: "usca", name: "USA & Canada", surcharge: 1.99),
                SenderOrigin(id: "world", name: "Rest of World", surcharge: 2.99)
            ]
        case .austria, .france, .italy, .spain, .netherlands, .otherEEA, .sweden, .norway:
            [
                .domestic("Domestic & EEA"),
                SenderOrigin(id: "uk", name: "United Kingdom", surcharge: 1.29),
                SenderOrigin(id: "world", name: "Rest of World", surcharge: 1.99)
            ]
        case .switzerland:
            [
                .domestic(),
                SenderOrigin(id: "eeauk", name: "EEA & United Kingdom", surcharge: 1.29),
                SenderOrigin(id: "world", name: "Rest of World", surcharge: 1.99)
            ]
        case .unitedKingdom:
            [
                .domestic(),
                SenderOrigin(id: "eea", name: "EEA", surcharge: 1.29),
                SenderOrigin(id: "world", name: "Rest of World", surcharge: 1.99)
            ]
        case .unitedStates:
            [.domestic(), SenderOrigin(id: "intl", name: "International", surcharge: 1.5)]
        case .canada:
            [
                .domestic(),
                SenderOrigin(id: "us", name: "USA", surcharge: 0.8),
                SenderOrigin(id: "world", name: "Rest of World", surcharge: 1)
            ]
        case .australia:
            [.domestic(), SenderOrigin(id: "intl", name: "International", surcharge: 1)]
        case .mexico:
            [.domestic(), SenderOrigin(id: "intl", name: "International", surcharge: 0.5)]
        case .india:
            // PayPal India only supports international payments; the surcharge is part of the rate.
            [SenderOrigin(id: "domestic", name: "International", surcharge: 0)]
        case .custom:
            [.domestic(), SenderOrigin(id: "intl", name: "International", surcharge: customSurcharge)]
        }
    }

    /// Short note shown below the rates, if a market has a peculiarity.
    var note: LocalizedStringResource? {
        switch self {
        case .germany: "Rate for direct goods & services payments. PayPal Checkout in online shops costs 2.99 % + 0.39 €."
        case .unitedStates: "Rate for goods & services payments between PayPal accounts. PayPal Checkout costs 3.49 % + $0.49."
        case .mexico: "Includes 16 % VAT on the fee."
        case .india: "PayPal India only supports international payments. The fixed fee depends on the received currency."
        case .otherEEA: "Most common rate in the EEA. Check PayPal's fee page for your country."
        default: nil
        }
    }

    /// The preset matching the device's region, so the app is correct on first launch.
    static var suggested: FeeRegion {
        let code = Locale.current.region?.identifier ?? ""
        if let match = allCases.first(where: { $0.regionCode == code }) {
            return match
        }
        let eea: Set = ["BE", "BG", "CY", "CZ", "DK", "EE", "FI", "GR", "HR", "HU", "IE", "IS", "LI", "LT", "LU", "LV", "MT", "PL", "PT", "RO", "SI", "SK"]
        return eea.contains(code) ? .otherEEA : .unitedStates
    }

    /// The presets listed in the picker, sorted by localized name.
    static var presets: [FeeRegion] {
        allCases
            .filter { $0 != .custom && $0 != .otherEEA }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            + [.otherEEA]
    }

    private static func flagEmoji(for regionCode: String) -> String {
        regionCode.unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map(String.init)
            .joined()
    }
}
