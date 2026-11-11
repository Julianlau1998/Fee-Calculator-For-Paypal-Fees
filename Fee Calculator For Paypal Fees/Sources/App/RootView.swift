//
//  RootView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AdsManager.self) private var ads
    @Environment(ProStore.self) private var pro
    @Environment(CalculatorModel.self) private var calculator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppTheme.colorKey) private var themeColor = ThemeColor.paypal
    @AppStorage(AppTheme.backgroundKey) private var backgroundStyle = BackgroundStyle.subtle

    /// The chosen appearance with Pro, otherwise the default.
    private var theme: AppTheme {
        pro.isPro ? AppTheme(color: themeColor, background: backgroundStyle) : .default
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Calculator", systemImage: "plusminus.circle.fill", value: AppTab.calculator) {
                CalculatorView()
            }
            Tab("Fee Table", systemImage: "tablecells", value: AppTab.table) {
                FeeTableView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: router.selectedTab) {
            ads.registerTabSwitch()
        }
        // Switching between send and receive (calculator or fee table) is a finished action.
        .onChange(of: calculator.mode) {
            ads.registerCompletedAction()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                ads.sceneDidEnterBackground()
            case .active:
                ads.sceneDidBecomeActive(canInterrupt: !router.isShowingPaywall && !router.isShowingWelcome)
            default:
                break
            }
        }
        .sheet(isPresented: $router.isShowingWelcome) {
            WelcomeView {
                UserDefaults.standard.set(WelcomeView.currentVersion, forKey: WelcomeView.storageKey)
                router.isShowingWelcome = false
            }
        }
        .sheet(isPresented: $router.isShowingPaywall) {
            PaywallView()
        }
        .task { await router.observeKeyboard(showing: true) }
        .task { await router.observeKeyboard(showing: false) }
        .onChange(of: pro.isPro, initial: true) { _, isPro in
            ads.isAdFree = isPro
        }
        // Ask for consent only once the welcome sheet is gone (so the forms don't stack)
        // and StoreKit has confirmed that Pro isn't active.
        .task(id: AdStartCondition(isShowingWelcome: router.isShowingWelcome, isPro: pro.isPro, hasChecked: pro.hasCheckedEntitlements)) {
            guard !router.isShowingWelcome, pro.hasCheckedEntitlements, !pro.isPro else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await ads.start()
        }
        #if DEBUG
        .task { ScreenshotDemo.prepare(router: router, calculator: calculator, context: modelContext) }
        #endif
        // Last, so the sheets get the theme too.
        .environment(\.theme, theme)
        .tint(theme.accent)
    }
}

private struct AdStartCondition: Equatable {
    let isShowingWelcome: Bool
    let isPro: Bool
    let hasChecked: Bool
}

/// Shows the shared banner above the tab bar, but not while typing or with Pro.
/// The tab bar doesn't minimize on scroll, otherwise the banner would float above an empty gap.
private struct AdBannerInset: ViewModifier {
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 8) {
            if ads.showsAds && !router.isKeyboardVisible {
                BannerAdView()
            }
        }
    }
}

extension View {
    func adBanner() -> some View {
        modifier(AdBannerInset())
    }
}
