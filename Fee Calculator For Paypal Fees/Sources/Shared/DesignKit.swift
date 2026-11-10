//
//  DesignKit.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// White symbol on a colored rounded square, as in the Settings app.
struct IconTile: View {
    let systemImage: String
    /// Defaults to the theme color.
    var color: Color?
    var size: CGFloat = 29

    @Environment(\.theme) private var theme

    var body: some View {
        let color = color ?? theme.accent
        Image(systemName: systemImage)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct IconLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var color: Color?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            IconTile(systemImage: systemImage, color: color, size: 28)
        }
    }
}

/// Mesh gradient in the theme color for the result card.
struct HeroMesh: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.45], [0.6, 0.4], [1, 0.55],
                    [0, 1], [0.45, 1], [1, 1]
                ],
                colors: theme.color.meshColors
            )
            // Soft highlight in the top-left corner for depth.
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
        }
        .animation(.smooth, value: theme)
    }
}

/// Wallet-style card for the headline result.
struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroMesh() }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}

/// Grouped background with a soft glow in the theme color behind the large title.
struct AppBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        let intensity = theme.background.intensity
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [theme.accent.opacity(intensity.top), theme.accent.opacity(intensity.middle), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.45)
            )
        }
        .ignoresSafeArea()
        .animation(.smooth, value: theme)
    }
}

/// Capsule switch with Liquid Glass, e.g. "Send · Receive".
struct CapsuleToggle<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: LocalizedStringResource)]

    @Namespace private var namespace
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(theme.accent.gradient)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension View {
    func appListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background { AppBackground() }
    }

    /// Places a card edge-to-edge inside a list section.
    func cardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Number pads have no return key, so offer a "Done" button while the keyboard is up.
    func keyboardDoneButton(isVisible: Bool) -> some View {
        toolbar {
            if isVisible {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        WindowHelper.dismissKeyboard()
                    }
                }
            }
        }
    }
}
