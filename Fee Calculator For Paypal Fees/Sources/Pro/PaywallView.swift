//
//  PaywallView.swift
//  Fee Calculator For Paypal Fees
//

import StoreKit
import SwiftUI

/// What Pro unlocks, shown on the paywall and in Settings.
enum ProFeature: CaseIterable, Identifiable {
    case noAds, profit, export, themes

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .noAds: "No Ads"
        case .profit: "Profit Calculator"
        case .export: "Export History"
        case .themes: "Themes"
        }
    }

    /// One line, for rows in lists.
    var shortSubtitle: LocalizedStringResource {
        switch self {
        case .noAds: "No banners, no full-screen ads."
        case .profit: "Profit, margin and minimum price after fees."
        case .export: "Saved calculations as a CSV file."
        case .themes: "Your own theme color and background."
        }
    }

    /// The longer pitch on the first paywall step.
    var pitch: LocalizedStringResource {
        switch self {
        case .noAds: "Calculate without banners and full-screen ads – also no more consent prompts."
        case .profit: "See your profit and margin after PayPal fees, and the minimum price for your target profit."
        case .export: "Export all saved calculations as a CSV file for Excel, Numbers or your tax return."
        case .themes: "Choose your theme color and how strongly the background glows."
        }
    }

    var systemImage: String {
        switch self {
        case .noAds: "nosign"
        case .profit: "chart.line.uptrend.xyaxis"
        case .export: "tablecells.badge.ellipsis"
        case .themes: "paintpalette.fill"
        }
    }

    var color: Color {
        switch self {
        case .noAds: .pink
        case .profit: .green
        case .export: .orange
        case .themes: .purple
        }
    }
}

/// Two steps: first what Pro offers, then Apple's plan picker.
struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    // Screenshot demo: the App Review screenshot shows the plan picker.
    @State private var isShowingPlans = ScreenshotDemo.isActive && ScreenshotDemo.screen == .plans
    #else
    @State private var isShowingPlans = false
    #endif

    var body: some View {
        NavigationStack {
            ProBenefitsPage {
                isShowingPlans = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $isShowingPlans) {
                ProPlansPage()
            }
        }
        .onChange(of: pro.isPro) { _, isPro in
            // Also covers "Restore Purchases" and purchases approved later (Ask to Buy).
            if isPro { dismiss() }
        }
    }
}

/// Step 1: the benefits, with one clear button to continue.
private struct ProBenefitsPage: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background { HeroMesh() }
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Fee Calculator Pro")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Calculate without distractions and get more out of every sale.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ProFeature.allCases) { feature in
                        HStack(alignment: .top, spacing: 14) {
                            IconTile(systemImage: feature.systemImage, color: feature.color, size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feature.title)
                                    .font(.headline)
                                Text(feature.pitch)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background { AppBackground() }
    }
}

/// Step 2: Apple's subscription store to pick a plan.
private struct ProPlansPage: View {
    @Environment(ProStore.self) private var pro

    var body: some View {
        SubscriptionStoreView(productIDs: ProConfig.productIDs) {
            VStack(spacing: 6) {
                Text("Choose Your Plan")
                    .font(.title.bold())
                Text("Cancel anytime in the App Store settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: ProConfig.termsOfUse, for: .termsOfService)
        .containerBackground(for: .subscriptionStoreFullHeight) { AppBackground() }
        // Inside a navigation stack the store sits on the navigation container's background.
        .containerBackground(for: .navigation) { AppBackground() }
        // Also behind the loading state, before the store has its own background.
        .background { AppBackground() }
        .onInAppPurchaseCompletion { _, result in
            // Dismissal follows from `isPro` changing.
            if case .success(.success) = result {
                await pro.refreshEntitlements()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A row for a Pro tool: opens it with Pro, otherwise the paywall.
struct ProToolLink<Destination: View>: View {
    let feature: ProFeature
    @ViewBuilder let destination: () -> Destination

    @Environment(ProStore.self) private var pro
    @Environment(AppRouter.self) private var router

    var body: some View {
        if pro.isPro {
            NavigationLink {
                destination()
            } label: {
                label
            }
        } else {
            Button {
                router.isShowingPaywall = true
            } label: {
                HStack {
                    label
                    Spacer()
                    ProBadge()
                }
                .contentShape(.rect)
            }
            .tint(.primary)
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: feature.systemImage, color: feature.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.shortSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Small "PRO" capsule next to locked features.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.gradient, in: .capsule)
            .accessibilityLabel(Text("Pro feature"))
    }
}
