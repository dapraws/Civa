//
//  ButtonStyles.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Civa's buttons (DESIGN.md §7.1). One Primary per page; Claude style only for Claude actions.
struct CivaButtonStyle: ButtonStyle {
    enum Kind {
        case primary, secondary, textLink, destructive, destructiveFill, claude
    }

    let kind: Kind
    /// nil follows the surrounding `.controlSize`.
    var size: ControlSize?
    /// Only for `.textLink`: the label color when it isn't `accentText`, such as `claudeText`.
    var color: Color?

    init(_ kind: Kind, size: ControlSize? = nil, color: Color? = nil) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        CivaButton(kind: kind, size: size, linkColor: color ?? .accentText, configuration: configuration)
    }
}

extension View {
    /// A Civa button style without the system focus ring, which draws in the macOS accent
    /// color beside Civa's own ring. Use this instead of `.buttonStyle(CivaButtonStyle(…))`.
    func civaButton(_ kind: CivaButtonStyle.Kind, size: ControlSize? = nil, color: Color? = nil) -> some View {
        buttonStyle(CivaButtonStyle(kind, size: size, color: color)).focusEffectDisabled()
    }
}

extension ButtonStyle where Self == CivaButtonStyle {
    static var primary: CivaButtonStyle { CivaButtonStyle(.primary) }
    static var secondary: CivaButtonStyle { CivaButtonStyle(.secondary) }
    /// Not `.link` or `.plain`: SwiftUI already has those.
    static var textLink: CivaButtonStyle { CivaButtonStyle(.textLink) }
    static var destructive: CivaButtonStyle { CivaButtonStyle(.destructive) }
    static var destructiveFill: CivaButtonStyle { CivaButtonStyle(.destructiveFill) }
    static var claude: CivaButtonStyle { CivaButtonStyle(.claude) }
}

private struct CivaButton: View {
    let kind: CivaButtonStyle.Kind
    let size: ControlSize?
    let linkColor: Color
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    private var height: CGFloat {
        switch size ?? controlSize {
        case .small, .mini: Size.controlSmall
        case .large, .extraLarge: Size.controlLarge
        default: Size.control
        }
    }

    private var isPressed: Bool { configuration.isPressed }
    private var hovers: Bool { isHovered && isEnabled }

    var body: some View {
        Group {
            if kind == .textLink {
                configuration.label
                    .foregroundStyle(linkColor)
                    .underline(hovers)
                    .opacity(isPressed ? 0.7 : 1)
                    .frame(minHeight: Size.minTarget)
                    .contentShape(.rect)
            } else {
                label
                    .lineLimit(1)
                    .fixedSize()
                    .font(kind == .secondary || kind == .destructive ? .body.weight(.medium) : .bodyEmphasis)
                    .foregroundStyle(foreground)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: height)
                    .background(fill, in: .rect(cornerRadius: Radius.control))
                    .overlay {
                        if let border {
                            RoundedRectangle(cornerRadius: Radius.control).strokeBorder(border)
                        }
                    }
                    .contentShape(.rect(cornerRadius: Radius.control))
            }
        }
        .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isFocused)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: hovers)
        .animation(Motion.fast, value: isPressed)
    }

    /// Claude buttons always lead with the spark; a label's own icon is dropped so there's one.
    @ViewBuilder private var label: some View {
        if kind == .claude {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkles")
                    .accessibilityHidden(true)
                configuration.label.labelStyle(.titleOnly)
            }
        } else {
            configuration.label
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .destructiveFill: .onAccent
        case .secondary: .textPrimary
        case .claude: .claudeText
        case .destructive: .danger
        case .textLink: linkColor
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary:
            AnyShapeStyle(isPressed ? Color.accentPressed : hovers ? Color.accentHover : Color.accent)
        case .secondary, .destructive:
            AnyShapeStyle(isPressed ? Color.selectionFill : hovers ? Color.hover : Color.surface)
        case .claude:
            // Hover and pressed tints are color sets so the label keeps 4.5:1 (DesignTokenTests).
            AnyShapeStyle(isPressed ? Color.claudeTintPressed : hovers ? Color.claudeTintHover : Color.claudeTint)
        case .destructiveFill:
            AnyShapeStyle(Color.dangerFill.mix(with: .black, by: isPressed || hovers ? 0.08 : 0))
        case .textLink:
            AnyShapeStyle(Color.clear)
        }
    }

    private var border: Color? {
        switch kind {
        case .secondary, .destructive: .fieldBorder
        case .claude: .claudeBorder
        default: nil
        }
    }
}

private struct ButtonGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([ControlSize.small, .regular, .large], id: \.self) { size in
                HStack(spacing: 8) {
                    Button("New Resume") {}.buttonStyle(CivaButtonStyle(.primary, size: size))
                    Button("Import…") {}.buttonStyle(CivaButtonStyle(.secondary, size: size))
                    Button("Start") {}.buttonStyle(CivaButtonStyle(.textLink, size: size))
                    Button("Delete") {}.buttonStyle(CivaButtonStyle(.destructive, size: size))
                    Button("Delete") {}.buttonStyle(CivaButtonStyle(.destructiveFill, size: size))
                    Button("Ask Claude", systemImage: "sparkles") {}.buttonStyle(CivaButtonStyle(.claude, size: size))
                }
            }
            HStack(spacing: 8) {
                Button("New Resume") {}.buttonStyle(.primary)
                Button("Import…") {}.buttonStyle(.secondary)
                Button("Ask Claude", systemImage: "sparkles") {}.buttonStyle(.claude)
            }
            .disabled(true)
        }
        .padding()
        .background(Color.canvas)
    }
}

#Preview { ButtonGallery() }

#Preview("Dark") { ButtonGallery().preferredColorScheme(.dark) }
