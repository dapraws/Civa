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
    /// `byKeyboard` tells it the keys moved focus here when it can't see that itself, such as a
    /// board card picked with the arrow keys.
    func civaFocusRing(_ shape: some InsettableShape, isFocused: Bool, byKeyboard: Bool = false) -> some View {
        modifier(FocusRing(shape: shape, isFocused: isFocused, byKeyboard: byKeyboard))
    }
}

private struct FocusRing<S: InsettableShape>: ViewModifier {
    let shape: S
    let isFocused: Bool
    let byKeyboard: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var fromKeyboard = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isFocused && (fromKeyboard || byKeyboard) {
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
