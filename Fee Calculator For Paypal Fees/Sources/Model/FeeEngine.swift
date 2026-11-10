//
//  FeeEngine.swift
//  Fee Calculator For Paypal Fees
//

import Foundation

/// Which question the calculator answers.
nonisolated enum CalculationMode: String, CaseIterable, Identifiable, Codable {
    /// "Someone pays me X – how much arrives after fees?"
    case send
    /// "X should arrive – how much do I have to ask for?"
    case receive

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .send: "Send"
        case .receive: "Receive"
        }
    }

    var inputTitle: LocalizedStringResource {
        switch self {
        case .send: "Amount Sent"
        case .receive: "Amount to Receive"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .send: "Enter the amount that is sent. You'll see the fees and how much arrives."
        case .receive: "Enter how much should arrive. You'll see how much to request so the fees are covered."
        }
    }
}

/// Everything that determines the fee of one payment.
nonisolated struct FeeParameters: Hashable {
    /// Total percentage including the cross-border surcharge, e.g. 2.49.
    var percent: Double
    var fixed: Double
    /// Tax on the fee in percent, e.g. 16 (Mexico).
    var feeTax: Double = 0
    /// Currency conversion spread in percent, or `nil` if no conversion takes place.
    var conversionSpread: Double?
    /// Number of decimals of the currency (2 for EUR, 0 for JPY).
    var fractionDigits: Int = 2
}

/// The result of one calculation, always expressed from the sender's gross amount.
nonisolated struct FeeBreakdown: Hashable {
    /// What the sender pays.
    let gross: Double
    let percentageFee: Double
    let fixedFee: Double
    let taxOnFee: Double
    let conversionFee: Double
    /// What arrives in the recipient's account.
    let net: Double
    /// The fee is at least as high as the payment, so nothing arrives.
    let feeExceedsAmount: Bool

    var paypalFee: Double { percentageFee + fixedFee + taxOnFee }
    var totalFees: Double { paypalFee + conversionFee }
    /// Share of the gross amount that goes to fees, 0…1.
    var effectiveRate: Double { gross > 0 ? totalFees / gross : 0 }

    static let zero = FeeBreakdown(gross: 0, percentageFee: 0, fixedFee: 0, taxOnFee: 0, conversionFee: 0, net: 0, feeExceedsAmount: false)
}

/// PayPal fee math. Fees are charged on the gross amount: `fee = gross × p + fixed`.
nonisolated enum FeeEngine {
    /// Forward calculation: the sender pays `gross`, how much arrives?
    static func breakdown(gross: Double, parameters: FeeParameters) -> FeeBreakdown {
        guard gross > 0, gross.isFinite else { return .zero }
        let digits = parameters.fractionDigits
        let taxFactor = parameters.feeTax / 100

        let percentagePart = gross * parameters.percent / 100
        // PayPal rounds the whole fee once; the parts are derived from it so they always add up.
        let paypalFee = round((percentagePart + parameters.fixed) * (1 + taxFactor), digits)
        let percentageFee = round(percentagePart, digits)
        let fixedFee = parameters.fixed
        let taxOnFee = max(0, paypalFee - percentageFee - fixedFee)

        let afterPayPal = max(0, gross - paypalFee)
        let conversionFee = parameters.conversionSpread.map { round(afterPayPal * $0 / 100, digits) } ?? 0
        let net = max(0, afterPayPal - conversionFee)

        return FeeBreakdown(
            gross: gross,
            percentageFee: percentageFee,
            fixedFee: fixedFee,
            taxOnFee: taxOnFee,
            conversionFee: conversionFee,
            net: net,
            feeExceedsAmount: paypalFee >= gross
        )
    }

    /// Reverse calculation: how much must be requested so that at least `net` arrives?
    /// Returns `nil` if the rates make that impossible (100 % fees or more).
    static func breakdown(net target: Double, parameters: FeeParameters) -> FeeBreakdown? {
        guard target > 0, target.isFinite else { return .zero }
        let taxFactor = 1 + parameters.feeTax / 100
        let conversionFactor = 1 - (parameters.conversionSpread ?? 0) / 100
        let percentFactor = 1 - parameters.percent / 100 * taxFactor
        guard conversionFactor > 0, percentFactor > 0 else { return nil }

        // gross − (gross × p + fixed) × tax = target / (1 − conversion)
        let beforeConversion = target / conversionFactor
        let exact = (beforeConversion + parameters.fixed * taxFactor) / percentFactor

        // Rounding the fee can make a slightly smaller amount suffice, so start a few
        // currency units below the exact value and step up to the first amount that works.
        let unit = pow(10, -Double(parameters.fractionDigits))
        var gross = max(unit, ((exact / unit).rounded(.down) - 3) * unit)
        var result = breakdown(gross: gross, parameters: parameters)
        var steps = 0
        while result.net + unit / 2 < target, steps < 40 {
            gross += unit
            result = breakdown(gross: gross, parameters: parameters)
            steps += 1
        }
        return result
    }

    /// Rounds half away from zero to the given number of decimals, like PayPal.
    static func round(_ value: Double, _ digits: Int) -> Double {
        let factor = pow(10, Double(digits))
        // The tiny nudge compensates binary floating point, e.g. 2.835 stored as 2.83499….
        let scaled = value * factor
        return (scaled + (scaled >= 0 ? 1e-7 : -1e-7)).rounded(.toNearestOrAwayFromZero) / factor
    }
}
