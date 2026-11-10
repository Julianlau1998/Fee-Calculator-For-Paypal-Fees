//
//  WelcomeView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// "Welcome / What's New" sheet shown on first launch and after major updates.
struct WelcomeView: View {
    /// Increase to show the sheet again after an update with notable changes.
    static let currentVersion = 1
    static let storageKey = "welcome.lastSeenVersion"

    static var needsPresentation: Bool {
        UserDefaults.standard.integer(forKey: storageKey) < currentVersion
    }

    let onContinue: () -> Void

    @State private var isAnimating = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 18) {
                        Image(systemName: "plusminus.circle.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background { HeroMesh() }
                            .clipShape(.rect(cornerRadius: 22, style: .continuous))
                            .shadow(color: theme.accent.opacity(0.35), radius: 16, y: 8)
                            .scaleEffect(isAnimating ? 1 : 0.6)
                            .opacity(isAnimating ? 1 : 0)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("Fee Calculator")
                                .font(.largeTitle.bold())
                            Text("Completely rebuilt – faster, clearer and with current PayPal rates.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 12)
                    }
                    .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            WelcomeFeatureRow(feature: feature)
                                .opacity(isAnimating ? 1 : 0)
                                .offset(y: isAnimating ? 0 : 16)
                                .animation(.smooth(duration: 0.6).delay(0.15 + Double(index) * 0.08), value: isAnimating)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Text("Not affiliated with PayPal. All information without guarantee.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .frame(maxWidth: 560)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) { isAnimating = true }
        }
        .interactiveDismissDisabled()
    }

    private var features: [WelcomeFeature] {
        [
            WelcomeFeature(
                title: "Send & Receive",
                message: "See what arrives after fees – or how much to request so the fees are covered.",
                systemImage: "arrow.left.arrow.right.circle.fill", color: .blue
            ),
            WelcomeFeature(
                title: "Current Rates for 16 Markets",
                message: "From Germany to the USA, or enter your own rates.",
                systemImage: "globe.europe.africa.fill", color: .teal
            ),
            WelcomeFeature(
                title: "International Payments",
                message: "Cross-border surcharges and currency conversion are included.",
                systemImage: "airplane.circle.fill", color: .orange
            ),
            WelcomeFeature(
                title: "Fee Table & History",
                message: "Fees for typical amounts at a glance, and saved calculations for later.",
                systemImage: "tablecells.fill", color: .indigo
            )
        ]
    }
}

private struct WelcomeFeature {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let color: Color
}

private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 36

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: feature.systemImage)
                .font(.system(size: iconSize * 0.8, weight: .medium))
                .foregroundStyle(feature.color.gradient)
                .symbolRenderingMode(.hierarchical)
                .frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView {}
}
