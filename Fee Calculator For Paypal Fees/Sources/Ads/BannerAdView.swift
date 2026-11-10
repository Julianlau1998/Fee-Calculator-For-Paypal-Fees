//
//  BannerAdView.swift
//  Fee Calculator For Paypal Fees
//

import GoogleMobileAds
import Observation
import OSLog
import SwiftUI
import UIKit

/// One banner, loaded once consent allows it and moved into whichever tab is visible,
/// so switching tabs never reloads it or leaves an empty gap.
@Observable
final class SharedBanner: NSObject, BannerViewDelegate {
    static let shared = SharedBanner()

    /// An ad has loaded and can be shown.
    private(set) var isLoaded = false
    private(set) var height: CGFloat = 0

    @ObservationIgnored let bannerView = BannerView()
    @ObservationIgnored private var loadedWidth: CGFloat = 0
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var isEnabled = false

    private override init() {
        super.init()
        bannerView.adUnitID = AdConfig.bannerUnitID
        bannerView.delegate = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
    }

    /// Starts loading for the window's width. Called once the SDK has started.
    func preload() {
        isEnabled = true
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        let width = scene?.keyWindow?.bounds.width ?? scene?.screen.bounds.width ?? 0
        if bannerView.rootViewController == nil {
            bannerView.rootViewController = WindowHelper.topViewController
        }
        load(width: width)
    }

    /// All containers currently in a window, so the banner can move back when one disappears.
    @ObservationIgnored private let containers = NSHashTable<UIView>.weakObjects()

    /// A container appeared: the newest one gets the banner (e.g. a pushed screen).
    fileprivate func containerDidAppear(_ container: UIView) {
        containers.add(container)
        attach(to: container)
    }

    /// A container left the window: hand the banner to another visible one.
    fileprivate func containerDidDisappear(_ container: UIView) {
        containers.remove(container)
        guard bannerView.superview === container else { return }
        if let next = containers.allObjects.last(where: { $0.window != nil }) {
            attach(to: next)
        }
    }

    /// Layout pass of a container. Only reacts if this container owns the banner or nobody
    /// visible does – two visible containers must never pull the banner back and forth.
    fileprivate func containerDidLayout(_ container: UIView) {
        let owner = bannerView.superview
        guard owner === container || owner?.window == nil else { return }
        attach(to: container)
    }

    /// Moves the banner into a container. Reloads only if the width changed (iPad, Stage Manager).
    private func attach(to container: UIView) {
        guard isEnabled, let window = container.window else { return }
        if bannerView.superview !== container {
            bannerView.removeFromSuperview()
            container.addSubview(bannerView)
            NSLayoutConstraint.activate([
                bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                bannerView.topAnchor.constraint(equalTo: container.topAnchor)
            ])
        }
        bannerView.rootViewController = window.rootViewController
        load(width: window.bounds.width)
    }

    private func load(width: CGFloat) {
        let widthChanged = abs(width - loadedWidth) > 1
        guard width > 0, !isLoading, widthChanged else { return }
        loadedWidth = width
        isLoading = true
        // Adaptive width, but capped in height: the large anchored size (~126 pt) took too much space.
        bannerView.adSize = inlineAdaptiveBanner(width: min(width, 728), maxHeight: AdConfig.bannerMaxHeight)
        bannerView.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoading = false
        // Inline adaptive ads report their final height once loaded.
        let reported = bannerView.adSize.size.height
        let newHeight = reported > 0 ? min(reported, AdConfig.bannerMaxHeight) : AdConfig.bannerMaxHeight
        if height != newHeight { height = newHeight }
        if !isLoaded { isLoaded = true }
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
        isLoading = false
        adsLog.error("Banner failed: \(error.localizedDescription, privacy: .public)")
        // Keep showing a previously loaded ad; otherwise try again later.
        guard !isLoaded else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            self.loadedWidth = 0
            self.preload()
        }
    }
}

/// The shared banner, taking up space only once an ad has loaded.
struct BannerAdView: View {
    private let banner = SharedBanner.shared

    var body: some View {
        BannerHost()
            .frame(height: banner.isLoaded ? banner.height : 0)
            .frame(maxWidth: .infinity)
            .clipped()
            .opacity(banner.isLoaded ? 1 : 0)
            // Keep a gap to the tab bar; solid behind ad and gap so list content doesn't show through.
            .padding(.bottom, banner.isLoaded ? AdConfig.bannerBottomSpacing : 0)
            .background(banner.isLoaded ? Color(.systemGroupedBackground) : .clear)
            .accessibilityHidden(!banner.isLoaded)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Advertisement"))
    }
}

private struct BannerHost: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerContainerView {
        BannerContainerView()
    }

    func updateUIView(_ uiView: BannerContainerView, context: Context) {}
}

/// Takes the shared banner in whenever it's on screen.
final class BannerContainerView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            SharedBanner.shared.containerDidAppear(self)
        } else {
            SharedBanner.shared.containerDidDisappear(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if window != nil { SharedBanner.shared.containerDidLayout(self) }
    }
}
