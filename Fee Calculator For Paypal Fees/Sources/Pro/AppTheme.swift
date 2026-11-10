//
//  AppTheme.swift
//  Fee Calculator For Paypal Fees
//

import SwiftUI

/// Pro: the app's theme color, used for the tint, the result card and the background glow.
enum ThemeColor: String, CaseIterable, Identifiable {
    case paypal, ocean, violet, rose, sunset, forest, graphite

    var id: Self { self }

    var name: LocalizedStringResource {
        switch self {
        case .paypal: "PayPal Blue"
        case .ocean: "Ocean"
        case .violet: "Violet"
        case .rose: "Rose"
        case .sunset: "Sunset"
        case .forest: "Forest"
        case .graphite: "Graphite"
        }
    }

    var accent: Color {
        switch self {
        case .paypal: Color(red: 0.00, green: 0.44, blue: 0.86)
        case .ocean: Color(red: 0.00, green: 0.55, blue: 0.62)
        case .violet: Color(red: 0.42, green: 0.30, blue: 0.86)
        case .rose: Color(red: 0.86, green: 0.22, blue: 0.47)
        case .sunset: Color(red: 0.93, green: 0.42, blue: 0.10)
        case .forest: Color(red: 0.13, green: 0.55, blue: 0.30)
        case .graphite: Color(red: 0.30, green: 0.32, blue: 0.36)
        }
    }

    /// Nine colors for the 3 × 3 mesh of the result card, dark at the bottom.
    var meshColors: [Color] {
        switch self {
        case .paypal:
            [
                Color(red: 0.00, green: 0.19, blue: 0.53), Color(red: 0.00, green: 0.30, blue: 0.70), Color(red: 0.00, green: 0.38, blue: 0.75),
                Color(red: 0.02, green: 0.16, blue: 0.46), Color(red: 0.04, green: 0.32, blue: 0.74), Color(red: 0.00, green: 0.42, blue: 0.70),
                Color(red: 0.01, green: 0.11, blue: 0.36), Color(red: 0.02, green: 0.20, blue: 0.52), Color(red: 0.00, green: 0.30, blue: 0.56)
            ]
        case .ocean: Self.mesh(hue: 0.52, saturation: 0.95)
        case .violet: Self.mesh(hue: 0.71, saturation: 0.75)
        case .rose: Self.mesh(hue: 0.94, saturation: 0.80)
        case .sunset: Self.mesh(hue: 0.06, saturation: 0.90)
        case .forest: Self.mesh(hue: 0.39, saturation: 0.85)
        case .graphite: Self.mesh(hue: 0.62, saturation: 0.12)
        }
    }

    /// Same brightness pattern as the PayPal mesh, with a slight hue shift for depth.
    private static func mesh(hue: Double, saturation: Double) -> [Color] {
        let brightness: [Double] = [0.53, 0.70, 0.75, 0.46, 0.74, 0.70, 0.36, 0.52, 0.56]
        let hueShift: [Double] = [-0.015, 0, 0.012, -0.02, 0, 0.015, -0.02, -0.005, 0.01]
        return zip(brightness, hueShift).map { value, shift in
            Color(hue: (hue + shift + 1).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: value)
        }
    }
}

/// How strongly the theme color glows behind the large titles.
enum BackgroundStyle: String, CaseIterable, Identifiable {
    case off, subtle, vivid

    var id: Self { self }

    var name: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .vivid: "Vivid"
        }
    }

    /// Opacity of the glow at the top and in the middle.
    var intensity: (top: Double, middle: Double) {
        switch self {
        case .off: (0, 0)
        case .subtle: (0.22, 0.06)
        case .vivid: (0.45, 0.14)
        }
    }
}

/// The resolved appearance. Without Pro it's always the default.
struct AppTheme: Equatable {
    var color: ThemeColor = .paypal
    var background: BackgroundStyle = .subtle

    static let `default` = AppTheme()

    static let colorKey = "theme.color"
    static let backgroundKey = "theme.background"

    var accent: Color { color.accent }
}

extension EnvironmentValues {
    @Entry var theme: AppTheme = .default
}
