//
//  FocusRing.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import AppKit
import SwiftUI

extension View {
    /// DESIGN.md §7.1: a 2 pt ring, 2 pt outside the shape, cobalt in light and `accentText` in
    /// dark. Only for keyboard focus: focus that arrives with a mouse click shows nothing.
    /// Pair with `.focusEffectDisabled()` so the system ring doesn't show as well.
    func civaFocusRing(_ shape: some InsettableShape, isFocused: Bool) -> some View {
        modifier(FocusRing(shape: shape, isFocused: isFocused))
    }
}

private struct FocusRing<S: InsettableShape>: ViewModifier {
    let shape: S
    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var fromKeyboard = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isFocused && fromKeyboard {
                    shape
                        .inset(by: -3)
                        .stroke(colorScheme == .dark ? Color.accentText : Color.accent, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: isFocused, initial: true) { _, focused in
                // ponytail: keyboard focus = the event that moved focus was a key press (Tab).
                fromKeyboard = focused && NSApp?.currentEvent?.type == .keyDown
            }
    }
}
