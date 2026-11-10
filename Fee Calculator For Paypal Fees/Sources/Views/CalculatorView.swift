//
//  CalculatorView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftData
import SwiftUI

struct CalculatorView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AppRouter.self) private var router
    @Environment(AdsManager.self) private var ads
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isNamingCalculation = false
    @State private var calculationName = ""
    @State private var savedCount = 0

    var body: some View {
        let breakdown = calculator.breakdown

        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    // iPad and wide windows: results left, inputs right.
                    HStack(alignment: .top, spacing: 0) {
                        Form {
                            resultSections(breakdown)
                            moreSections
                        }
                        Form {
                            modeSection
                            amountSection
                            paymentSection
                        }
                        .frame(width: 420)
                    }
                } else {
                    // The result sits right below the amount, so it stays visible while typing.
                    Form {
                        modeSection
                        amountSection
                        resultSections(breakdown)
                        paymentSection
                        breakdownSection(breakdown)
                        moreSections
                    }
                    .listSectionSpacing(.compact)
                }
            }
            .navigationTitle("Fee Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .appListStyle()
            .adBanner()
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton(isVisible: router.isKeyboardVisible)
            .toolbar { toolbar(breakdown) }
            .alert("Save Calculation", isPresented: $isNamingCalculation) {
                TextField("Name (optional)", text: $calculationName)
                Button("Save") { save(breakdown) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("For example the buyer or the item, so you can find it later.")
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    // MARK: Inputs

    private var modeSection: some View {
        @Bindable var calculator = calculator

        return Section {
            CapsuleToggle(
                selection: $calculator.mode,
                options: CalculationMode.allCases.map { ($0, $0.title) }
            )
            .cardRow()
        }
    }

    private var amountSection: some View {
        @Bindable var calculator = calculator

        return Section {
            AmountField(
                title: calculator.mode.inputTitle,
                text: $calculator.amountText,
                currencyCode: calculator.currencyCode
            )
            .accessibilityHint(Text(calculator.mode.explanation))
        }
    }

    private var paymentSection: some View {
        @Bindable var calculator = calculator

        return Section {
            NavigationLink {
                RegionPickerView()
            } label: {
                HStack(spacing: 12) {
                    Text(verbatim: calculator.region.flag)
                        .font(.title2)
                        .frame(width: 29)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fee Profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(verbatim: calculator.region.name)
                    }
                    Spacer()
                    Text(verbatim: calculator.rateSummary)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if calculator.origins.count > 1 {
                // A menu with the value below the title (like the fee profile row), because a
                // regular picker wraps long localized names like "Deutschland & EWR" awkwardly.
                Menu {
                    Picker(selection: $calculator.originID) {
                        ForEach(calculator.origins) { origin in
                            Text(origin.name).tag(origin.id)
                        }
                    } label: {
                        Text("Sender Location")
                    }
                } label: {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "globe.europe.africa.fill", color: .teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sender Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(calculator.origin.name)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                // Menu labels inherit the accent color; keep the row neutral like the one above.
                .tint(.primary)
                .accessibilityValue(Text(calculator.origin.name))
                .sensoryFeedback(.selection, trigger: calculator.originID)
            }

            Toggle(isOn: $calculator.convertsCurrency) {
                HStack(spacing: 12) {
                    IconTile(systemImage: "arrow.left.arrow.right", color: .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Currency Conversion")
                        Text("+ \(Formatting.percent(calculator.rates.conversionSpread)) above the exchange rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Payment")
        } footer: {
            if let note = calculator.region.note {
                Text(note)
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private func resultSections(_ breakdown: FeeBreakdown?) -> some View {
        if let breakdown {
            Section {
                ResultCard(breakdown: breakdown, mode: calculator.mode, currencyCode: calculator.currencyCode)
                    .cardRow()
            }
            if horizontalSizeClass == .regular {
                breakdownSection(breakdown)
            }
        } else {
            Section {
                Label("With these rates the fees would be 100 % or more. Please check the custom rates.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func breakdownSection(_ breakdown: FeeBreakdown?) -> some View {
        if let breakdown {
            BreakdownSection(breakdown: breakdown, currencyCode: calculator.currencyCode, percent: calculator.parameters.percent, showsTax: calculator.rates.feeTax > 0)
        }
    }

    /// Pro tools and the disclaimer at the end.
    @ViewBuilder
    private var moreSections: some View {
        Section {
            ProToolLink(feature: .profit) {
                ProfitCalculatorView()
            }
        } header: {
            Text("Tools")
        } footer: {
            Text("Not affiliated with PayPal. Rates according to PayPal's published fee schedules; all information without guarantee.")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbar(_ breakdown: FeeBreakdown?) -> some ToolbarContent {
        if !router.isKeyboardVisible {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let breakdown, breakdown.gross > 0 {
                    ShareLink(item: shareText(breakdown)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button("Save", systemImage: "bookmark") {
                        calculationName = ""
                        isNamingCalculation = true
                    }
                }
            }
        }
    }

    private func save(_ breakdown: FeeBreakdown?) {
        guard let breakdown, let amount = calculator.amount else { return }
        let entry = SavedCalculation(
            title: calculationName.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: calculator.mode,
            amount: amount,
            breakdown: breakdown,
            currencyCode: calculator.currencyCode,
            rateSummary: calculator.rateSummary
        )
        modelContext.insert(entry)
        savedCount += 1
        ReviewPrompter.registerSignificantEvent()
        ads.registerCompletedAction()
    }

    private func shareText(_ breakdown: FeeBreakdown) -> String {
        let code = calculator.currencyCode
        var lines = [
            String(localized: "PayPal fees (\(calculator.region.name), \(calculator.rateSummary))"),
            String(localized: "Amount sent: \(Formatting.currency(breakdown.gross, code: code))"),
            String(localized: "Fees: \(Formatting.currency(breakdown.totalFees, code: code))"),
            String(localized: "Arrives: \(Formatting.currency(breakdown.net, code: code))")
        ]
        if calculator.mode == .receive {
            lines.append(String(localized: "Please send \(Formatting.currency(breakdown.gross, code: code)) so that \(Formatting.currency(breakdown.net, code: code)) arrive after PayPal fees."))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Amount field

/// The large amount input with the currency symbol.
struct AmountField: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let currencyCode: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let symbol = Formatting.currencySymbol(for: currencyCode)
                let isLeading = Formatting.currencySymbolIsLeading(currencyCode)
                if isLeading { symbolText(symbol) }
                TextField(text: $text, prompt: Text(verbatim: zeroPlaceholder)) {
                    Text(title)
                }
                .keyboardType(.decimalPad)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber || $0 == "." || $0 == "," }.prefix(12))
                    if filtered != newValue { text = filtered }
                }
                if !isLeading { symbolText(symbol) }
                if !text.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        text = ""
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tertiary)
                    .buttonStyle(.plain)
                    .font(.title3)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }

    private var zeroPlaceholder: String {
        0.0.formatted(.number.precision(.fractionLength(Formatting.fractionDigits(for: currencyCode))))
    }

    private func symbolText(_ symbol: String) -> some View {
        Text(verbatim: symbol)
            .font(.system(size: 28, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Result card

/// The headline result: what arrives (send) or what to request (receive).
struct ResultCard: View {
    let breakdown: FeeBreakdown
    let mode: CalculationMode
    let currencyCode: String

    var body: some View {
        let headline = mode == .send ? breakdown.net : breakdown.gross

        HeroCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label(mode == .send ? "Arrives" : "Request", systemImage: mode == .send ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    ResultBadge(systemImage: "chart.pie.fill") {
                        Text(verbatim: Formatting.percent(breakdown.effectiveRate * 100))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Effective rate \(Formatting.percent(breakdown.effectiveRate * 100))"))
                }

                Text(verbatim: Formatting.currency(headline, code: currencyCode))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: headline))

                ShareBar(net: breakdown.net, fees: breakdown.totalFees)

                HStack(alignment: .firstTextBaseline) {
                    Text("Fees \(Formatting.currency(breakdown.totalFees, code: currencyCode))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 12)
                    Text(mode == .send
                         ? "of \(Formatting.currency(breakdown.gross, code: currencyCode)) sent"
                         : "so that \(Formatting.currency(breakdown.net, code: currencyCode)) arrive")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.trailing)
                }
            }
            .animation(.snappy, value: breakdown)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Capsule on the result card, e.g. "− Fees 2.84 €".
struct ResultBadge<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            content
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.18), in: .capsule)
    }
}

/// Horizontal bar: the part that arrives vs. the part lost to fees.
private struct ShareBar: View {
    let net: Double
    let fees: Double

    var body: some View {
        let total = max(net + fees, 0.000_1)
        GeometryReader { proxy in
            HStack(spacing: 3) {
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: max(0, proxy.size.width * net / total - (fees > 0 ? 1.5 : 0)))
                if fees > 0 {
                    Capsule()
                        .fill(Color(red: 1, green: 0.62, blue: 0.35))
                }
            }
        }
        .frame(height: 8)
        .animation(.smooth, value: net)
        .accessibilityHidden(true)
    }
}

// MARK: - Breakdown

struct BreakdownSection: View {
    let breakdown: FeeBreakdown
    let currencyCode: String
    let percent: Double
    let showsTax: Bool

    var body: some View {
        Section {
            row("Amount Sent", breakdown.gross)
            row("\(Formatting.percent(percent)) of the amount", -breakdown.percentageFee, isDetail: true)
            if breakdown.fixedFee > 0 {
                row("Fixed Fee", -breakdown.fixedFee, isDetail: true)
            }
            if showsTax {
                row("VAT on the Fee", -breakdown.taxOnFee, isDetail: true)
            }
            if breakdown.conversionFee > 0 {
                row("Currency Conversion", -breakdown.conversionFee, isDetail: true)
            }
            row("Total Fees", -breakdown.totalFees)
            row("Arrives", breakdown.net, isEmphasized: true)

            if breakdown.feeExceedsAmount {
                Label("The fee is higher than the amount. Nothing would arrive.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Breakdown")
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: Double, isDetail: Bool = false, isEmphasized: Bool = false) -> some View {
        let formatted = Formatting.currency(abs(value), code: currencyCode)
        return LabeledContent {
            Text(verbatim: (value < 0 ? "− " : "") + formatted)
                .monospacedDigit()
                .fontWeight(isEmphasized ? .bold : .regular)
                .foregroundStyle(isEmphasized ? Color.primary : (value < 0 ? Color.secondary : Color.primary))
                .contentTransition(.numericText(value: value))
        } label: {
            Text(title)
                .fontWeight(isEmphasized ? .semibold : .regular)
                .foregroundStyle(isDetail ? .secondary : .primary)
                .padding(.leading, isDetail ? 12 : 0)
        }
        .font(isDetail ? .subheadline : .body)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = Formatting.plainNumber(abs(value), fractionDigits: Formatting.fractionDigits(for: currencyCode))
            }
        }
    }
}
