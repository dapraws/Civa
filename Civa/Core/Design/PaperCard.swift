//
//  PaperCard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

extension View {
    /// A gallery thumbnail (DESIGN.md §7.9): the page on `desk` with a paper shadow, a
    /// `fieldBorder` outline on hover. The paper is the card; nothing wraps the title below it.
    func paperCard() -> some View {
        modifier(PaperCard())
    }
}

private struct PaperCard: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .clipShape(.rect(cornerRadius: Radius.tag))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.tag)
                    .strokeBorder(isHovered ? Color.fieldBorder : Color.hairline)
            }
            .paperShadow()
            .padding(Space.m)
            .background(Color.desk, in: .rect(cornerRadius: Radius.card))
            .onHover { isHovered = $0 }
            .animation(Motion.fast, value: isHovered)
    }
}

/// A small count on a card, such as suggested changes from the Career Profile. Tinted, not solid.
struct CountTag: View {
    let count: Int
    let systemImage: String

    var body: some View {
        Label("\(count)", systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color.accentText)
            .background(Color.accentTint, in: .rect(cornerRadius: Radius.tag))
    }
}
