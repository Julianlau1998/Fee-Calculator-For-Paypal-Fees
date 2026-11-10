//
//  AdsManager.swift
//  Fee Calculator For Paypal Fees
//

import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Observation
import OSLog
import UIKit
import UserMessagingPlatform

enum AdConfig {
    #if DEBUG
    // Google's test units: live ads in development builds can get the AdMob account suspended.
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let appOpenUnitID: String? = "ca-app-pub-3940256099942544/5575463023"
    #else
    static let bannerUnitID = "ca-app-pub-1006221991146598/2293592475"
    static let interstitialUnitID = "ca-app-pub-1006221991146598/5245309702"
    /// TODO: Create an "App open" ad unit in AdMob and enter its ID. Until then no app open ads are shown.
    static let appOpenUnitID: String? = nil
    #endif

    /// Height limit for the banner above the tab bar.
    static let bannerMaxHeight: CGFloat = 90
    /// Gap to the tab bar, so taps on a tab don't hit the ad by accident (AdMob placement policy).
    static let bannerBottomSpacing: CGFloat = 10

    /// Completed actions (save, share, mode switch, …) between two interstitials.
    static let actionsPerInterstitial = 3
    /// Tab switches count as an action only every n-th time.
    static let tabSwitchesPerAction = 3
    /// Minimum time between two interstitials.
    static let interstitialCooldown: TimeInterval = 2 * 60
    /// No interstitial right after launch, people want to calculate first.
    static let launchGracePeriod: TimeInterval = 60

    /// App open ads only from this launch on, never on the very first start.
    static let appOpenMinimumLaunches = 2
    /// Returning to the app shows an app open ad only after this long in the background.
    static let appOpenBackgroundThreshold: TimeInterval = 30
    /// Minimum time since the last full-screen ad of any kind.
    static let appOpenCooldown: TimeInterval = 60
    /// On a cold start the ad must be ready this soon after launch, otherwise it's skipped.
    static let appOpenColdStartWindow: TimeInterval = 8
    /// Google: app open ads expire four hours after loading.
    static let appOpenExpiry: TimeInterval = 4 * 60 * 60
}

nonisolated let adsLog = Logger(subsystem: "app.paypal-fee-calculator", category: "Ads")

/// Gathers consent (UMP / GDPR) and tracking permission, starts AdMob and decides when
/// a full-screen ad may appear: only at natural breaks, never while someone is typing.
///
/// Ad requests never contain amounts or any other data entered in the app.
@Observable
final class AdsManager: NSObject {
    private static let launchCountKey = "ads.launchCount"

    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false
    /// Pro is active: no banner, no full-screen ads, no consent prompts.
    var isAdFree = false

    /// Whether the banner may be shown right now.
    var showsAds: Bool { canRequestAds && !isAdFree }

    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var appOpenAd: AppOpenAd?
    @ObservationIgnored private var appOpenLoadedAt = Date.distantPast
    @ObservationIgnored private var isLoadingAppOpenAd = false
    @ObservationIgnored private var isPresentingFullScreenAd = false
    @ObservationIgnored private var completedActions = 0
    @ObservationIgnored private var tabSwitches = 0
    @ObservationIgnored private var lastFullScreenAd = Date.distantPast
    @ObservationIgnored private var enteredBackgroundAt: Date?
    @ObservationIgnored private let startedAt = Date.now
    @ObservationIgnored private let launchCount: Int

    override init() {
        let count = UserDefaults.standard.integer(forKey: Self.launchCountKey) + 1
        UserDefaults.standard.set(count, forKey: Self.launchCountKey)
        launchCount = count
        super.init()
    }

    /// Consent form → ATT → SDK start → preload ads. Safe to call more than once.
    func start() async {
        guard !hasStarted, !isAdFree else { return }
        hasStarted = true

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: WindowHelper.topViewController)
        } catch {
            // Fall back to the last known consent state.
            adsLog.error("Consent gathering failed: \(error.localizedDescription, privacy: .public)")
        }

        // Ask for tracking after Google's consent form, so personalized ads are possible.
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            try? await Task.sleep(for: .milliseconds(500))
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        refreshConsentState()

        guard canRequestAds, !isAdFree else {
            adsLog.info("No ads: consent missing or Pro")
            return
        }
        #if DEBUG
        MobileAds.shared.isApplicationMuted = true
        #endif
        await MobileAds.shared.start()
        SharedBanner.shared.preload()

        // Cold start: show an app open ad only if it's ready right away.
        await loadAppOpenAd()
        if Date.now.timeIntervalSince(startedAt) <= AdConfig.appOpenColdStartWindow {
            showAppOpenAdIfAllowed()
        }
        await loadInterstitial()
    }

    /// Shows Google's privacy options so people can change their choice (Settings).
    func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: WindowHelper.topViewController)
        refreshConsentState()
    }

    private func refreshConsentState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    // MARK: Interstitial

    /// Call after a finished action such as saving or switching the mode. Shows an ad only occasionally.
    func registerCompletedAction() {
        guard showsAds else { return }
        completedActions += 1
        guard completedActions >= AdConfig.actionsPerInterstitial,
              !isPresentingFullScreenAd,
              Date.now.timeIntervalSince(startedAt) >= AdConfig.launchGracePeriod,
              Date.now.timeIntervalSince(lastFullScreenAd) >= AdConfig.interstitialCooldown else { return }
        guard let interstitial else {
            Task { await loadInterstitial() }
            return
        }

        completedActions = 0
        lastFullScreenAd = .now
        isPresentingFullScreenAd = true
        // Let the triggering UI (sheet, menu, toggle) finish its animation first.
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            interstitial.present(from: WindowHelper.topViewController)
        }
        self.interstitial = nil
    }

    /// Tab changes are natural breaks; every few switches count as one action.
    func registerTabSwitch() {
        tabSwitches += 1
        guard tabSwitches >= AdConfig.tabSwitchesPerAction else { return }
        tabSwitches = 0
        registerCompletedAction()
    }

    private func loadInterstitial() async {
        guard showsAds, interstitial == nil else { return }
        do {
            let ad = try await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            adsLog.error("Interstitial failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: App open ad

    func sceneDidEnterBackground() {
        enteredBackgroundAt = .now
    }

    /// Returning to the app after a while is a natural moment for an app open ad.
    /// - Parameter canInterrupt: `false` while a sheet such as the paywall is open.
    func sceneDidBecomeActive(canInterrupt: Bool) {
        guard let enteredBackgroundAt else { return }
        self.enteredBackgroundAt = nil
        guard canInterrupt,
              Date.now.timeIntervalSince(enteredBackgroundAt) >= AdConfig.appOpenBackgroundThreshold else { return }
        showAppOpenAdIfAllowed()
    }

    private func showAppOpenAdIfAllowed() {
        guard showsAds,
              launchCount >= AdConfig.appOpenMinimumLaunches,
              !isPresentingFullScreenAd,
              Date.now.timeIntervalSince(lastFullScreenAd) >= AdConfig.appOpenCooldown else { return }
        guard let appOpenAd, Date.now.timeIntervalSince(appOpenLoadedAt) < AdConfig.appOpenExpiry else {
            self.appOpenAd = nil
            Task { await loadAppOpenAd() }
            return
        }

        self.appOpenAd = nil
        lastFullScreenAd = .now
        isPresentingFullScreenAd = true
        WindowHelper.dismissKeyboard()
        appOpenAd.present(from: WindowHelper.topViewController)
    }

    private func loadAppOpenAd() async {
        guard showsAds, let unitID = AdConfig.appOpenUnitID,
              launchCount >= AdConfig.appOpenMinimumLaunches,
              appOpenAd == nil, !isLoadingAppOpenAd else { return }
        isLoadingAppOpenAd = true
        defer { isLoadingAppOpenAd = false }
        do {
            let ad = try await AppOpenAd.load(with: unitID, request: Request())
            ad.fullScreenContentDelegate = self
            appOpenAd = ad
            appOpenLoadedAt = .now
        } catch {
            adsLog.error("App open ad failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A full-screen ad closed or failed: allow the next one and preload a replacement.
    private func fullScreenAdDidFinish(isAppOpenAd: Bool) async {
        isPresentingFullScreenAd = false
        if isAppOpenAd {
            await loadAppOpenAd()
        } else {
            await loadInterstitial()
        }
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        let isAppOpenAd = ad is AppOpenAd
        Task { @MainActor in await self.fullScreenAdDidFinish(isAppOpenAd: isAppOpenAd) }
    }

    nonisolated func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        let isAppOpenAd = ad is AppOpenAd
        Task { @MainActor in await self.fullScreenAdDidFinish(isAppOpenAd: isAppOpenAd) }
    }
}

@MainActor
enum WindowHelper {
    /// The view controller on top, used to present consent and ad UI.
    static var topViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
