//
//  CalculatorModel.swift
//  Fee Calculator For Paypal Fees
//

import Foundation
import Observation

/// The calculator's state. Settings are persisted in `UserDefaults` on every change.
@Observable
final class CalculatorModel {
    private enum Key {
        static let mode = "calculator.mode"
        static let amount = "calculator.amount"
        static let region = "fees.region"
        static let origin = "fees.origin"
        static let converts = "fees.convertsCurrency"
        static let customRates = "fees.customRates"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var mode: CalculationMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    /// The amount as typed, so the field keeps exactly what the user entered.
    var amountText: String {
        didSet { defaults.set(amountText, forKey: Key.amount) }
    }

    var region: FeeRegion {
        didSet {
            defaults.set(region.rawValue, forKey: Key.region)
            // Each market has different sender tiers; keep the choice only if it still exists.
            if !origins.contains(where: { $0.id == originID }) {
                originID = origins[0].id
            }
        }
    }

    var originID: String {
        didSet { defaults.set(originID, forKey: Key.origin) }
    }

    /// The payment is made in a different currency and converted by PayPal.
    var convertsCurrency: Bool {
        didSet { defaults.set(convertsCurrency, forKey: Key.converts) }
    }

    var customRates: FeeRates {
        didSet {
            if let data = try? JSONEncoder().encode(customRates) {
                defaults.set(data, forKey: Key.customRates)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Key.mode).flatMap(CalculationMode.init) ?? .send
        amountText = defaults.string(forKey: Key.amount) ?? ""
        region = defaults.string(forKey: Key.region).flatMap(FeeRegion.init) ?? .suggested
        originID = defaults.string(forKey: Key.origin) ?? "domestic"
        convertsCurrency = defaults.bool(forKey: Key.converts)
        customRates = defaults.data(forKey: Key.customRates)
            .flatMap { try? JSONDecoder().decode(FeeRates.self, from: $0) }
            ?? FeeRates(percent: 2.49, fixed: 0.35, currencyCode: Locale.current.currency?.identifier ?? "EUR")
    }

    // MARK: Derived values

    var rates: FeeRates { region.rates ?? customRates }

    var currencyCode: String { rates.currencyCode }

    var origins: [SenderOrigin] { region.origins(customSurcharge: customRates.internationalSurcharge) }

    var origin: SenderOrigin { origins.first { $0.id == originID } ?? origins[0] }

    var amount: Double? { AmountParser.parse(amountText) }

    var parameters: FeeParameters {
        FeeParameters(
            percent: rates.percent + origin.surcharge,
            fixed: rates.fixed,
            feeTax: rates.feeTax,
            conversionSpread: convertsCurrency ? rates.conversionSpread : nil,
            fractionDigits: Formatting.fractionDigits(for: currencyCode)
        )
    }

    /// The result for the current input, `nil` if the rates make the calculation impossible.
    var breakdown: FeeBreakdown? {
        breakdown(for: amount ?? 0, mode: mode)
    }

    func breakdown(for amount: Double, mode: CalculationMode) -> FeeBreakdown? {
        switch mode {
        case .send: FeeEngine.breakdown(gross: amount, parameters: parameters)
        case .receive: FeeEngine.breakdown(net: amount, parameters: parameters)
        }
    }

    /// "2.49 % + 0.35 €" for the current profile and sender origin.
    var rateSummary: String {
        Formatting.rateSummary(percent: parameters.percent, fixed: rates.fixed, currencyCode: currencyCode)
    }

    func setAmount(_ value: Double) {
        amountText = Formatting.plainNumber(value, fractionDigits: Formatting.fractionDigits(for: currencyCode))
    }
}

/// Parses amounts typed with either "," or "." as decimal separator.
nonisolated enum AmountParser {
    static func parse(_ text: String) -> Double? {
        let allowed = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !allowed.isEmpty else { return nil }
        // The last separator is the decimal separator; earlier ones are grouping.
        var normalized = allowed
        if let index = allowed.lastIndex(where: { $0 == "." || $0 == "," }) {
            let integerPart = allowed[..<index].filter(\.isNumber)
            let fractionPart = allowed[allowed.index(after: index)...].filter(\.isNumber)
            normalized = (integerPart.isEmpty ? "0" : integerPart) + "." + fractionPart
        }
        return Double(normalized)
    }
}
