//
//  OviBubble.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Ovi's message (DESIGN.md §9.2): grows upward from the perch inside the sidebar, never over
/// page content. Focus moves into it when it opens; Esc closes it.
struct OviBubble: View {
    let match: OviMatch
    let act: (OviAction) -> Void
    let close: () -> Void
    let why: () -> Void
    let dontShowAgain: () -> Void
    let turnOff: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: Space.xs) {
                Text(match.title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: Size.minTarget, height: Size.minTarget)
                    .contentShape(.rect)
                    // Focusable even without Full Keyboard Access, so focus lands in the bubble.
                    .focusable()
                    .focused($isFocused)
                    .help("Close")
            }
            Text(match.body)
                .font(.callout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(match.source)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s) {
                if let action = match.action {
                    Button(action.title) { act(action) }
                        .civaButton(.textLink)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Why?", action: why)
                    Button("Don't Show This Again", action: dontShowAgain)
                    Divider()
                    Button("Turn Off Ovi", action: turnOff)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: Size.minTarget, height: Size.minTarget)
                        .contentShape(.rect)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .fixedSize()
                .accessibilityLabel("More")
                .help("More")
            }
        }
        .padding(10)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
        .overlay(alignment: .bottomLeading) {
            // The tail points down at Ovi.
            Rectangle()
                .fill(Color.surface)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))
                .offset(x: 26, y: 4)
                .accessibilityHidden(true)
        }
        .popoverShadow()
        .onAppear { isFocused = true }
        .onExitCommand(perform: close)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Ovi: \(match.title). \(match.body)"))
    }
}

#Preview {
    OviBubble(
        match: OviRules.longestVariants[0],
        act: { _ in }, close: {}, why: {}, dontShowAgain: {}, turnOff: {}
    )
    .frame(width: 180)
    .padding()
    .background(Color.sidebar)
}

#Preview("Dark") {
    OviBubble(
        match: OviRules.longestVariants[0],
        act: { _ in }, close: {}, why: {}, dontShowAgain: {}, turnOff: {}
    )
    .frame(width: 180)
    .padding()
    .background(Color.sidebar)
    .preferredColorScheme(.dark)
}
