//
//  FeeTableView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// Fees for typical amounts at a glance, e.g. to set prices.
struct FeeTableView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AppRouter.self) private var router
    @Environment(AdsManager.self) private var ads

    private static let amounts: [Double] = [1, 5, 10, 20, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000]

    var body: some View {
        @Bindable var calculator = calculator
        let code = calculator.currencyCode

        NavigationStack {
            Form {
                Section {
                    CapsuleToggle(
                        selection: $calculator.mode,
                        options: CalculationMode.allCases.map { ($0, $0.title) }
                    )
                    .cardRow()
                }

                Section {
                    Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 0) {
                        GridRow {
                            Text(calculator.mode == .send ? "Sent" : "Arrives")
                                .gridColumnAlignment(.leading)
                            Text("Fees")
                            Text(calculator.mode == .send ? "Arrives" : "Request")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 8)

                        ForEach(Self.amounts, id: \.self) { amount in
                            Divider()
                            row(for: amount, code: code)
                        }
                    }
                    .padding(.vertical, 6)
                    // Without this the form row is measured taller than the grid and leaves a gap on top.
                    .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text(verbatim: "\(calculator.region.flag) \(calculator.region.name) · \(calculator.rateSummary)")
                        .textCase(nil)
                } footer: {
                    Text("Tap an amount to open it in the calculator. Sender location and currency conversion from the calculator are taken into account.")
                }
            }
            .navigationTitle("Fee Table")
            .appListStyle()
            .adBanner()
        }
    }

    @ViewBuilder
    private func row(for amount: Double, code: String) -> some View {
        if let breakdown = calculator.breakdown(for: amount, mode: calculator.mode) {
            let result = calculator.mode == .send ? breakdown.net : breakdown.gross
            GridRow {
                Text(verbatim: Formatting.currency(amount, code: code))
                    .fontWeight(.medium)
                Text(verbatim: Formatting.currency(breakdown.totalFees, code: code))
                    .foregroundStyle(.secondary)
                Text(verbatim: Formatting.currency(result, code: code))
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 11)
            .contentShape(.rect)
            .onTapGesture {
                calculator.setAmount(amount)
                router.selectedTab = .calculator
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }
}
