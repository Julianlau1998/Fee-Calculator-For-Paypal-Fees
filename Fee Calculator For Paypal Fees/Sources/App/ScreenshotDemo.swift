//
//  ScreenshotDemo.swift
//  Fee Calculator For Paypal Fees
//

#if DEBUG
import Foundation
import SwiftData

/// Debug builds only: `-screenshotDemo -screenshotScreen <name>` seeds sample data and opens a screen
/// for the App Store screenshots (see "StoreScreenshots Fee Calculator/tools/capture.sh").
/// Settings such as the market or the amount come in as launch arguments (`-fees.region germany`),
/// which override the stored values.
enum ScreenshotDemo {
    enum Screen: String {
        case calculator, receive, table, history, profit, markets, paywall, plans
    }

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-screenshotDemo") }

    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "screenshotScreen").flatMap(Screen.init)
    }

    @MainActor
    static func prepare(router: AppRouter, calculator: CalculatorModel, context: ModelContext) {
        guard isActive else { return }
        router.isShowingWelcome = false
        seedHistory(calculator: calculator, context: context)

        switch screen ?? .calculator {
        case .calculator:
            calculator.mode = .send
        case .receive:
            calculator.mode = .receive
        case .table:
            calculator.mode = .receive
            router.selectedTab = .table
        case .history:
            router.selectedTab = .history
        case .profit:
            router.demoShowsProfit = true
        case .markets:
            router.demoShowsMarkets = true
        case .paywall, .plans:
            router.isShowingPaywall = true
        }
    }

    /// A few saved calculations with names that fit the language.
    @MainActor
    private static func seedHistory(calculator: CalculatorModel, context: ModelContext) {
        try? context.delete(model: SavedCalculation.self)
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let titles = sampleTitles[language] ?? sampleTitles["en"]!
        // Kronor amounts are about ten times larger than euro amounts.
        let factor: Double = ["SEK", "NOK"].contains(calculator.currencyCode) ? 10 : 1
        let entries: [(CalculationMode, Double, TimeInterval)] = [
            (.send, 89, -2 * 3_600), (.receive, 250, -26 * 3_600), (.send, 34.90, -50 * 3_600),
            (.receive, 1_200, -4 * 86_400), (.send, 149, -6 * 86_400)
        ]
        for ((mode, amount, age), title) in zip(entries, titles) {
            let value = amount * factor
            guard let breakdown = calculator.breakdown(for: value, mode: mode) else { continue }
            let entry = SavedCalculation(title: title, mode: mode, amount: value, breakdown: breakdown,
                                         currencyCode: calculator.currencyCode, rateSummary: calculator.rateSummary)
            entry.date = .now.addingTimeInterval(age)
            context.insert(entry)
        }
    }

    private static let sampleTitles: [String: [String]] = [
        "de": ["Vintage-Kamera", "Logo-Design für Anna", "Konzertkarten", "Website-Projekt", "Sneaker"],
        "en": ["Vintage camera", "Logo design for Anna", "Concert tickets", "Website project", "Sneakers"],
        "fr": ["Appareil photo vintage", "Logo pour Anna", "Billets de concert", "Projet de site web", "Baskets"],
        "it": ["Fotocamera vintage", "Logo per Anna", "Biglietti del concerto", "Progetto sito web", "Sneaker"],
        "es": ["Cámara vintage", "Logo para Anna", "Entradas de concierto", "Proyecto web", "Zapatillas"],
        "nb": ["Vintagekamera", "Logo til Anna", "Konsertbilletter", "Nettsideprosjekt", "Joggesko"],
        "sv": ["Vintagekamera", "Logotyp till Anna", "Konsertbiljetter", "Webbprojekt", "Sneakers"]
    ]
}
#endif
