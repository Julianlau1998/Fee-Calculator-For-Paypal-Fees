//
//  SettingsView.swift
//  Fee Calculator For Paypal Fees
//

import StoreKit
import SwiftUI

enum AppLinks {
    static let privacyPolicy = URL(string: "https://paypal-fee-calculator.netlify.app/privacy")!
    static let contact = URL(string: "mailto:jlauapps@gmail.com")!
    static let paypalFees = URL(string: "https://www.paypal.com/webapps/mpp/merchant-fees")!
}

struct SettingsView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router
    @Environment(ProStore.self) private var pro
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @State private var isManagingSubscription = false
    @Environment(\.theme) private var theme

    @AppStorage(AppTheme.colorKey) private var themeColor = ThemeColor.paypal
    @AppStorage(AppTheme.backgroundKey) private var backgroundStyle = BackgroundStyle.subtle

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        RegionPickerView()
                    } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: calculator.region.flag)
                                .font(.title2)
                                .frame(width: 29)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: calculator.region.name)
                                Text(verbatim: calculator.rateSummary)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Link(destination: AppLinks.paypalFees) {
                        IconLabel(title: "PayPal Fee Overview", systemImage: "safari.fill", color: .blue)
                    }
                } header: {
                    Text("Fee Profile")
                } footer: {
                    Text("PayPal fees differ from country to country. Choose your PayPal market once and the calculator uses the right rates.")
                }

                proSection

                appearanceSection

                Section {
                    IconLabel(title: "Your amounts never leave your device.", systemImage: "lock.shield.fill", color: .green)
                    if ads.isPrivacyOptionsRequired && !pro.isPro {
                        Button {
                            Task { await ads.presentPrivacyOptions() }
                        } label: {
                            IconLabel(title: "Privacy Options for Ads", systemImage: "hand.raised.fill", color: .indigo)
                        }
                    }
                    Link(destination: AppLinks.privacyPolicy) {
                        IconLabel(title: "Privacy Policy", systemImage: "hand.raised.square.fill", color: .blue)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if !pro.isPro {
                        Text("This app shows ads from Google AdMob. Ad requests never contain the amounts you enter.")
                    }
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        IconLabel(title: "Rate the App", systemImage: "star.fill", color: .yellow)
                    }
                    Link(destination: AppLinks.contact) {
                        IconLabel(title: "Contact & Feedback", systemImage: "envelope.fill", color: .teal)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        IconLabel(title: "Language", systemImage: "globe", color: .purple)
                    }
                    Button {
                        router.isShowingWelcome = true
                    } label: {
                        IconLabel(title: "What's New", systemImage: "gift.fill", color: .pink)
                    }
                    LabeledContent {
                        Text(verbatim: Self.version)
                    } label: {
                        IconLabel(title: "Version", systemImage: "info.circle.fill", color: .gray)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("This app is not affiliated with PayPal. The rates were carefully researched from PayPal's published fee schedules, but no guarantee can be given that they are correct and up to date.")
                }

                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .appListStyle()
            .adBanner()
            .tint(.primary)
        }
        .tint(theme.accent)
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if pro.isPro {
                HStack(spacing: 14) {
                    IconTile(systemImage: "checkmark.seal.fill", color: .green, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro is active")
                            .font(.headline)
                        Text("Thank you for your support!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Button {
                    isManagingSubscription = true
                } label: {
                    IconLabel(title: "Manage Subscription", systemImage: "creditcard.fill", color: .gray)
                }
            } else {
                Button {
                    router.isShowingPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "sparkles", color: .orange, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fee Calculator Pro")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("No ads, profit calculator, CSV export and themes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                }
                Button {
                    Task { await pro.restore() }
                } label: {
                    IconLabel(title: "Restore Purchases", systemImage: "arrow.clockwise", color: .gray)
                }
            }
        } header: {
            Text(verbatim: "Pro")
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
    }

    /// Pro: theme color and background glow. Without Pro, tapping opens the paywall.
    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            // One row with all colors on iPhone.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: ThemeColor.allCases.count), spacing: 12) {
                ForEach(ThemeColor.allCases) { color in
                    let isSelected = pro.isPro ? color == themeColor : color == .paypal
                    Button {
                        if pro.isPro {
                            withAnimation(.smooth) { themeColor = color }
                        } else {
                            router.isShowingPaywall = true
                        }
                    } label: {
                        Circle()
                            .fill(color.accent.gradient)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(3)
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay {
                                Circle().strokeBorder(isSelected ? color.accent : .clear, lineWidth: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(color.name))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: themeColor)

            Picker(selection: Binding(
                get: { pro.isPro ? backgroundStyle : .subtle },
                set: { newValue in
                    if pro.isPro {
                        withAnimation(.smooth) { backgroundStyle = newValue }
                    } else {
                        router.isShowingPaywall = true
                    }
                }
            )) {
                ForEach(BackgroundStyle.allCases) { style in
                    Text(style.name).tag(style)
                }
            } label: {
                IconLabel(title: "Background", systemImage: "circle.lefthalf.filled", color: .indigo)
            }
        } header: {
            HStack(spacing: 6) {
                Text("Appearance")
                if !pro.isPro { ProBadge() }
            }
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        @Bindable var pro = pro
        Section {
            Toggle(isOn: $pro.simulatesPro) {
                Label {
                    Text(verbatim: "Simulate Pro")
                } icon: {
                    IconTile(systemImage: "ladybug.fill", color: .red, size: 28)
                }
            }
            .tint(theme.accent)
        } header: {
            Text(verbatim: "Debug")
        } footer: {
            Text(verbatim: "Only in debug builds. Unlocks all Pro features without a purchase.")
        }
    }
    #endif

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
