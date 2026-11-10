//
//  FeeCalculatorApp.swift
//  Fee Calculator For Paypal Fees
//

import SwiftData
import SwiftUI

@main
struct FeeCalculatorApp: App {
    @State private var calculator = CalculatorModel()
    @State private var router = AppRouter()
    @State private var ads = AdsManager()
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(calculator)
                .environment(router)
                .environment(ads)
                .environment(pro)
                .task { await pro.observeTransactions() }
        }
        .modelContainer(for: SavedCalculation.self)
    }
}
