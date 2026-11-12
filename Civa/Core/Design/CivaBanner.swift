//
//  CivaBanner.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// An in-app notice at the top of the content area (DESIGN.md §7.12). Claude banners get the
/// orange leading bar and `sparkles`; others use `info.circle`.
struct CivaBanner: View {
    let message: String
    var symbol = "info.circle"
    var isClaude = false
    let actionTitle: LocalizedStringKey
    let action: () -> Void
    let onClose: () -> Void

    init(
        message: String,
        symbol: String = "info.circle",
        isClaude: Bool = false,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.message = message
        self.symbol = isClaude ? "sparkles" : symbol
        self.isClaude = isClaude
        self.actionTitle = actionTitle
        self.action = action
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol)
                .foregroundStyle(isClaude ? Color.claude : Color.textSecondary)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(actionTitle, action: action)
                .civaButton(.textLink, color: isClaude ? .claudeText : nil)
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .frame(width: Size.minTarget, height: Size.minTarget)
                .contentShape(.rect)
                .help("Close")
        }
        .padding(Space.m)
        .background(Color.surfaceRaised, in: .rect(cornerRadius: Radius.card))
        .overlay(alignment: .leading) {
            if isClaude {
                UnevenRoundedRectangle(topLeadingRadius: Radius.card, bottomLeadingRadius: Radius.card)
                    .fill(Color.claude)
                    .frame(width: 3)
            }
        }
        .clipShape(.rect(cornerRadius: Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
        .popoverShadow()
        .frame(maxWidth: Size.readingWidth)
    }
}

private struct BannerPreview: View {
    var body: some View {
        VStack(spacing: Space.l) {
            CivaBanner(message: "Claude finished “Tailor to Stripe”.", isClaude: true, actionTitle: "Review", action: {}, onClose: {})
            CivaBanner(message: "Imported 12 records from your CV.", actionTitle: "Open", action: {}, onClose: {})
        }
        .padding(Space.xl)
        .background(Color.canvas)
    }
}

#Preview { BannerPreview() }

#Preview("Dark") { BannerPreview().preferredColorScheme(.dark) }
