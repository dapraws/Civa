//
//  DesignTokenTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import AppKit
import SwiftUI
import Testing
@testable import Civa

@MainActor
struct DesignTokenTests {
    /// name: (light, dark), from DESIGN.md §3. `claudeText` light is #A44A21: #A64B22 misses AA on selection.
    nonisolated static let tokens: [String: (String, String)] = [
        "canvas": ("FAF9F7", "121110"), "sidebar": ("F1EFEB", "161514"),
        "surface": ("FFFFFF", "1C1B19"), "surfaceRaised": ("FFFFFF", "23221F"),
        "hover": ("F0EDE8", "22211E"), "selectionFill": ("E7E3DC", "2A2824"),
        "hairline": ("E3E0DA", "302D29"), "fieldBorder": ("8F897F", "6E685F"),
        "desk": ("ECE9E3", "0C0B0A"), "textPrimary": ("1F1D1A", "F2EFEA"),
        "textSecondary": ("5F5A52", "A29C93"), "textTertiary": ("736D64", "8E887F"),
        "AccentColor": ("2649B8", "3A62D4"), "accentHover": ("1F3E9E", "4A70DE"),
        "accentPressed": ("1A3586", "3155C2"), "accentText": ("2649B8", "8EA8F2"),
        "accentTint": ("E6EBF8", "1E2742"), "onAccent": ("FFFFFF", "FFFFFF"),
        "claude": ("D97857", "E8946B"), "claudeText": ("A44A21", "E8946B"),
        "claudeTint": ("FBEDE5", "3A2419"), "claudeBorder": ("EBC9B5", "5A3524"),
        "statusNeutral": ("736D64", "8E887F"), "statusAmber": ("9A5B00", "E0A33A"),
        "statusGreen": ("1F7A4D", "4CC38A"), "statusRed": ("B42318", "F07167"),
        "danger": ("B42318", "F07167"), "dangerFill": ("B42318", "C9372C"),
        "success": ("1F7A4D", "4CC38A"), "warning": ("9A5B00", "E0A33A"),
        "claudeTintHover": ("F3E6DE", "402B20"), "claudeTintPressed": ("EEE1D9", "47322A"),
    ]

    @Test(arguments: tokens.keys.sorted())
    func tokenMatchesSpec(name: String) throws {
        let (light, dark) = try #require(Self.tokens[name])
        #expect(try hex(name, .aqua) == light)
        #expect(try hex(name, .darkAqua) == dark)
    }

    /// High-contrast appearances can't be created with `NSAppearance(named:)`, so this reads the
    /// color sets' source files instead of resolving the colors.
    @Test(arguments: [
        ("textSecondary", "4A463F", "C2BCB2"), ("fieldBorder", "6B665D", "8A847A"),
        ("hairline", "9C968C", "5E5952"), ("textTertiary", "4A463F", "C2BCB2"),
    ])
    func increaseContrastVariants(name: String, light: String, dark: String) throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Civa/Assets.xcassets/Colors/\(name).colorset/Contents.json")
        let set = try JSONDecoder().decode(ColorSetFile.self, from: Data(contentsOf: url))
        let highContrast = set.colors.filter { $0.appearances?.contains { $0.appearance == "contrast" && $0.value == "high" } == true }
        let isDark = { (entry: ColorSetFile.Entry) in entry.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } == true }
        #expect(highContrast.first { !isDark($0) }?.hex == light)
        #expect(highContrast.first(where: isDark)?.hex == dark)
    }

    /// DESIGN.md §3.5: (foreground, background, minimum ratio).
    @Test(arguments: [
        ("textPrimary", "selectionFill", 4.5), ("textSecondary", "sidebar", 4.5),
        ("textSecondary", "selectionFill", 4.5), ("textTertiary", "canvas", 4.5),
        ("textTertiary", "surface", 4.5), ("accentText", "selectionFill", 4.5),
        ("onAccent", "AccentColor", 4.5), ("onAccent", "accentHover", 4.5),
        ("claudeText", "sidebar", 4.5), ("claudeText", "claudeTint", 4.5),
        ("claudeText", "selectionFill", 4.5), ("accentText", "accentTint", 4.5),
        ("danger", "surface", 4.5), ("onAccent", "dangerFill", 4.5),
        ("fieldBorder", "surface", 3.0), ("fieldBorder", "canvas", 3.0),
        ("statusAmber", "selectionFill", 3.0), ("statusNeutral", "selectionFill", 3.0),
        ("claudeText", "claudeTintHover", 4.5), ("claudeText", "claudeTintPressed", 4.5),
        ("claudeText", "canvas", 4.5), ("claudeText", "surface", 4.5), ("accentText", "canvas", 4.5),
    ])
    func contrastPairsPassAA(foreground: String, background: String, minimum: Double) throws {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let ratio = try contrast(foreground, background, appearance)
            #expect(ratio >= minimum, "\(foreground) on \(background) in \(appearance.rawValue): \(ratio)")
        }
    }

    @Test func appearanceMapsToColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
        #expect(Appearance(rawValue: "unknown") == nil)
    }

    @Test func youngSerifRegisters() {
        CivaFonts.register()
        #expect(NSFont(name: "YoungSerif-Regular", size: 26) != nil)
    }

    private struct ColorSetFile: Decodable {
        struct Entry: Decodable {
            struct Appearance: Decodable { let appearance: String; let value: String }
            struct Color: Decodable { let components: [String: String] }
            let appearances: [Appearance]?
            let color: Color
            var hex: String {
                ["red", "green", "blue"].map { (color.components[$0] ?? "").replacingOccurrences(of: "0x", with: "") }.joined()
            }
        }
        let colors: [Entry]
    }

    private func components(_ name: String, _ appearance: NSAppearance.Name) throws -> (Double, Double, Double) {
        let color = try #require(NSColor(named: name), "Missing color set \(name)")
        var rgb: (Double, Double, Double) = (0, 0, 0)
        try #require(NSAppearance(named: appearance)).performAsCurrentDrawingAppearance {
            if let c = color.usingColorSpace(.sRGB) {
                rgb = (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
            }
        }
        return rgb
    }

    private func hex(_ name: String, _ appearance: NSAppearance.Name) throws -> String {
        let (r, g, b) = try components(name, appearance)
        return [r, g, b].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    private func contrast(_ foreground: String, _ background: String, _ appearance: NSAppearance.Name) throws -> Double {
        func luminance(_ rgb: (Double, Double, Double)) -> Double {
            func channel(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * channel(rgb.0) + 0.7152 * channel(rgb.1) + 0.0722 * channel(rgb.2)
        }
        let a = luminance(try components(foreground, appearance))
        let b = luminance(try components(background, appearance))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
