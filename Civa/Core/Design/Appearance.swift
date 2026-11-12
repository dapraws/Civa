//
//  Appearance.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI
import TipKit

/// Settings → Appearance (DESIGN.md §8.9). System follows macOS.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let key = "appearance"

    var id: Self { self }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

extension View {
    /// What every Civa window applies at its root: cobalt instead of the macOS accent color,
    /// the chosen appearance, and Civa's inline tip style.
    func civaWindowStyle() -> some View {
        modifier(CivaWindowStyle())
    }
}

private struct CivaWindowStyle: ViewModifier {
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    func body(content: Content) -> some View {
        content
            .tint(.accent)
            .tipViewStyle(CivaTipViewStyle())
            .preferredColorScheme(appearance.colorScheme)
    }
}

extension FocusedValues {
    /// Opens the Settings page, through the unsaved-changes guard. Set by the main window.
    @Entry var openSettings: (() -> Void)?
}

/// App menu → Settings… (⌘,).
struct SettingsCommand: View {
    @FocusedValue(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") { openSettings?() }
            .keyboardShortcut(",")
            .disabled(openSettings == nil)
    }
}
