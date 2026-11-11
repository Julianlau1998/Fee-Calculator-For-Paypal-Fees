//
//  AppRouter.swift
//  Fee Calculator For Paypal Fees
//

import Observation
import UIKit

enum AppTab: Hashable {
    case calculator, table, history, settings
}

/// App-wide navigation and UI state.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .calculator
    var isShowingWelcome = WelcomeView.needsPresentation
    var isShowingPaywall = false
    #if DEBUG
    /// Screenshot demo: pushes these screens in the calculator tab.
    var demoShowsProfit = false
    var demoShowsMarkets = false
    #endif
    private(set) var isKeyboardVisible = false

    /// Tracks the keyboard so the banner can step aside while typing.
    /// Runs for the lifetime of the calling task; start it once for each notification.
    func observeKeyboard(showing: Bool) async {
        let name = showing ? UIResponder.keyboardWillShowNotification : UIResponder.keyboardWillHideNotification
        for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
            isKeyboardVisible = showing
        }
    }
}
