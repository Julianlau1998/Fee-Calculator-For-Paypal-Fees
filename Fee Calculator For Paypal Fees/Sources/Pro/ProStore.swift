//
//  ProStore.swift
//  Fee Calculator For Paypal Fees
//

import Foundation
import Observation
import OSLog
import StoreKit

enum ProConfig {
    /// Auto-renewable subscriptions of the "Pro" group in App Store Connect.
    static let monthlyID = "paypalfeecalc.pro.monthly"
    static let yearlyID = "paypalfeecalc.pro.yearly"
    static let productIDs = [yearlyID, monthlyID]

    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

nonisolated let storeLog = Logger(subsystem: "app.paypal-fee-calculator", category: "Store")

/// Knows whether Pro is active and keeps that up to date with the App Store.
///
/// The last known state is cached, so Pro users never see an ad flash at launch,
/// even before StoreKit has answered.
@Observable
final class ProStore {
    private static let cacheKey = "pro.isActive"

    /// A verified subscription is active.
    private(set) var hasEntitlement: Bool {
        didSet { UserDefaults.standard.set(hasEntitlement, forKey: Self.cacheKey) }
    }
    /// StoreKit has confirmed the entitlement state at least once since launch.
    private(set) var hasCheckedEntitlements = false

    #if DEBUG
    private static let simulateKey = "debug.simulatesPro"

    /// Debug builds only: unlocks Pro without a purchase.
    var simulatesPro: Bool {
        didSet { UserDefaults.standard.set(simulatesPro, forKey: Self.simulateKey) }
    }

    var isPro: Bool { hasEntitlement || simulatesPro }

    init() {
        hasEntitlement = UserDefaults.standard.bool(forKey: Self.cacheKey)
        simulatesPro = UserDefaults.standard.bool(forKey: Self.simulateKey)
    }
    #else
    var isPro: Bool { hasEntitlement }

    init() {
        hasEntitlement = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }
    #endif

    /// Checks current entitlements, then follows renewals, refunds and purchases
    /// made on other devices for the lifetime of the calling task.
    func observeTransactions() async {
        await refreshEntitlements()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }

    /// Re-evaluates Pro from the verified, unrevoked transactions.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProConfig.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            active = true
        }
        if hasEntitlement != active { hasEntitlement = active }
        hasCheckedEntitlements = true
        storeLog.info("Pro active: \(active, privacy: .public)")
    }

    /// "Restore Purchases": syncs with the App Store (may ask the user to sign in).
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            storeLog.error("Restore failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
    }
}
