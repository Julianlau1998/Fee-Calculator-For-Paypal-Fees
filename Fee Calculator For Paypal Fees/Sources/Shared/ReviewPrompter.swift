//
//  ReviewPrompter.swift
//  Fee Calculator For Paypal Fees
//

import StoreKit
import UIKit

/// Asks for an App Store rating once, after the user saved a few calculations.
enum ReviewPrompter {
    private static let countKey = "review.significantEvents"
    private static let promptedKey = "review.hasPrompted"
    private static let threshold = 3

    static func registerSignificantEvent() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: promptedKey) else { return }
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)
        guard count >= threshold,
              let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        defaults.set(true, forKey: promptedKey)
        Task {
            try? await Task.sleep(for: .seconds(1))
            AppStore.requestReview(in: scene)
        }
    }
}
