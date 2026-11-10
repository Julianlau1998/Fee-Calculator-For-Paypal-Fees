//
//  RegionPickerView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// Choose the PayPal market whose fees apply, or enter custom rates.
struct RegionPickerView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var calculator = calculator

        Form {
            Section {
                ForEach(FeeRegion.presets) { region in
                    regionRow(region)
                }
            } header: {
                Text("PayPal Market")
            } footer: {
                Text("Rates for receiving payments for goods and services, according to PayPal's fee schedules (2026). Payments between friends and family in the same country are usually free.")
            }

            Section {
                regionRow(.custom)
                if calculator.region == .custom {
                    RateInputRow(title: "Percentage", value: $calculator.customRates.percent, unit: "%", systemImage: "percent", color: .blue)
                    RateInputRow(title: "Fixed Fee", value: $calculator.customRates.fixed, unit: Formatting.currencySymbol(for: calculator.customRates.currencyCode), systemImage: "banknote.fill", color: .green)
                    Picker(selection: $calculator.customRates.currencyCode) {
                        ForEach(Formatting.currencyCodes, id: \.self) { code in
                            Text(verbatim: "\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                                .tag(code)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: "dollarsign.circle.fill", color: .mint)
                            Text("Currency")
                        }
                    }
                    RateInputRow(title: "International Surcharge", value: $calculator.customRates.internationalSurcharge, unit: "%", systemImage: "globe", color: .teal)
                    RateInputRow(title: "Conversion Spread", value: $calculator.customRates.conversionSpread, unit: "%", systemImage: "arrow.left.arrow.right", color: .orange)
                }
            } header: {
                Text("Custom")
            } footer: {
                Text("Use your own rates, e.g. for a negotiated merchant rate or PayPal Checkout.")
            }
        }
        .navigationTitle("Fee Profile")
        .navigationBarTitleDisplayMode(.inline)
        .appListStyle()
        .adBanner()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton(isVisible: router.isKeyboardVisible)
        .sensoryFeedback(.selection, trigger: calculator.region)
    }

    private func regionRow(_ region: FeeRegion) -> some View {
        Button {
            guard calculator.region != region else { return }
            withAnimation(.snappy) { calculator.region = region }
            ads.registerCompletedAction()
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: region.flag)
                    .font(.title2)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: region.name)
                        .foregroundStyle(.primary)
                    let rates = region.rates ?? calculator.customRates
                    Text(verbatim: Formatting.rateSummary(percent: rates.percent, fixed: rates.fixed, currencyCode: rates.currencyCode))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if calculator.region == region {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(calculator.region == region ? .isSelected : [])
    }
}

/// A form row with a trailing numeric field and a unit.
struct RateInputRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let unit: String
    let systemImage: String
    var color: Color?

    @FocusState private var isFocused: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: systemImage, color: color)
            Text(title)
                .lineLimit(2)
                .layoutPriority(1)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .focused($isFocused)
                    .onChange(of: value) { _, newValue in
                        if newValue < 0 { value = 0 }
                    }
                Text(verbatim: unit)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 130, alignment: .trailing)
            .background(.fill.tertiary, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? (color ?? theme.accent) : .clear, lineWidth: 1.5)
            }
            .animation(.snappy(duration: 0.2), value: isFocused)
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}
