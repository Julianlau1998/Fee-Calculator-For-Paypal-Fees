//
//  ProfitCalculatorView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// Pro: what's left of a sale after PayPal fees and costs, and the price needed for a target profit.
/// Uses the calculator's fee profile, sender location and currency conversion.
struct ProfitCalculatorView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AppRouter.self) private var router

    @AppStorage("profit.price") private var priceText = ""
    @AppStorage("profit.cost") private var costText = ""
    @AppStorage("profit.shipping") private var shippingText = ""
    @AppStorage("profit.target") private var targetText = ""

    var body: some View {
        let code = calculator.currencyCode
        let price = AmountParser.parse(priceText) ?? 0
        let costs = (AmountParser.parse(costText) ?? 0) + (AmountParser.parse(shippingText) ?? 0)
        let fees = FeeEngine.breakdown(gross: price, parameters: calculator.parameters).totalFees
        let profit = price - fees - costs
        let margin = price > 0 ? profit / price : 0

        Form {
            Section {
                HeroCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profit")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(verbatim: Formatting.currency(profit, code: code))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText(value: profit))
                                .foregroundStyle(profit < 0 ? Color(red: 1, green: 0.62, blue: 0.55) : .white)
                        }
                        HStack(spacing: 8) {
                            ResultBadge(systemImage: "chart.pie.fill") {
                                Text("Margin \(Formatting.percent(margin * 100))")
                            }
                            ResultBadge(systemImage: "minus.circle.fill") {
                                Text("Fees \(Formatting.currency(fees, code: code))")
                            }
                        }
                    }
                    .animation(.snappy, value: profit)
                }
                .accessibilityElement(children: .combine)
                .cardRow()
            }

            Section {
                MoneyRow(title: "Sale Price", text: $priceText, currencyCode: code)
                MoneyRow(title: "Item Cost", text: $costText, currencyCode: code)
                MoneyRow(title: "Shipping Cost", text: $shippingText, currencyCode: code)
            } header: {
                Text("Sale")
            } footer: {
                Text("The sale price is what the buyer pays via PayPal, including shipping.")
            }

            Section {
                MoneyRow(title: "Target Profit", text: $targetText, currencyCode: code)
                if let target = AmountParser.parse(targetText), target > 0 {
                    if let needed = FeeEngine.breakdown(net: target + costs, parameters: calculator.parameters) {
                        LabeledContent("Minimum Price") {
                            Text(verbatim: Formatting.currency(needed.gross, code: code))
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(.tint)
                        }
                        .contextMenu {
                            Button("Use as Sale Price", systemImage: "arrow.up") {
                                priceText = Formatting.plainNumber(needed.gross, fractionDigits: Formatting.fractionDigits(for: code))
                            }
                        }
                    }
                }
            } header: {
                Text("Price for Target Profit")
            } footer: {
                Text("Uses your fee profile \(calculator.region.name) (\(calculator.rateSummary)) from the calculator.")
            }
        }
        .navigationTitle("Profit Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .appListStyle()
        .adBanner()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton(isVisible: router.isKeyboardVisible)
    }
}

/// A compact labeled amount input for forms.
struct MoneyRow: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let currencyCode: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField(text: $text, prompt: Text(verbatim: 0.0.formatted(.number.precision(.fractionLength(Formatting.fractionDigits(for: currencyCode)))))) {
                    Text(title)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onChange(of: text) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber || $0 == "." || $0 == "," }.prefix(12))
                    if filtered != newValue { text = filtered }
                }
                Text(verbatim: Formatting.currencySymbol(for: currencyCode))
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
        }
    }
}
