//
//  Metrics.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// DESIGN.md §5.1: a 4 pt grid.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

/// DESIGN.md §5.4. Continuous corners everywhere; no capsules.
enum Radius {
    static let tag: CGFloat = 4
    static let control: CGFloat = 6
    static let card: CGFloat = 10
    static let sheet: CGFloat = 14
}

/// DESIGN.md §5.2–§5.3.
enum Size {
    static let controlSmall: CGFloat = 22
    static let control: CGFloat = 28
    static let controlLarge: CGFloat = 32
    static let minTarget: CGFloat = 24
    static let sidebarItem: CGFloat = 28
    static let listRow: CGFloat = 44
    static let sectionRow: CGFloat = 32
    static let recordList: CGFloat = 260
    static let formMaxWidth: CGFloat = 680
    static let dashboardMaxWidth: CGFloat = 960
    static let readingWidth: CGFloat = 560
}

/// DESIGN.md §10. Quiet: nothing loops, nothing moves while idle.
enum Motion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeOut(duration: 0.2)
    static let emphasis = Animation.spring(response: 0.3, dampingFraction: 1.0)
}

/// DESIGN.md §5.5: the only shadows in Civa.
extension View {
    func paperShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 9, y: 6)
    }

    func popoverShadow() -> some View {
        modifier(PopoverShadow())
    }
}

private struct PopoverShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 12, y: 8)
    }
}
