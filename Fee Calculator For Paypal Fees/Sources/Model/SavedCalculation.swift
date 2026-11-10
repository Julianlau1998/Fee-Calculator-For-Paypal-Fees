//
//  SavedCalculation.swift
//  Fee Calculator For Paypal Fees
//

import Foundation
import SwiftData

/// A calculation the user saved to the history.
@Model
final class SavedCalculation {
    var date: Date = Date.now
    var title: String = ""
    var modeRawValue: String = CalculationMode.send.rawValue
    /// The amount the user entered.
    var amount: Double = 0
    var gross: Double = 0
    var totalFees: Double = 0
    var net: Double = 0
    var currencyCode: String = "EUR"
    /// "2.49 % + 0.35 €" at the time of saving.
    var rateSummary: String = ""

    init(title: String, mode: CalculationMode, amount: Double, breakdown: FeeBreakdown, currencyCode: String, rateSummary: String) {
        self.date = .now
        self.title = title
        self.modeRawValue = mode.rawValue
        self.amount = amount
        self.gross = breakdown.gross
        self.totalFees = breakdown.totalFees
        self.net = breakdown.net
        self.currencyCode = currencyCode
        self.rateSummary = rateSummary
    }

    var mode: CalculationMode { CalculationMode(rawValue: modeRawValue) ?? .send }
}
