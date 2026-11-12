//
//  EmptyStateView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// An empty page (DESIGN.md §7.13): one symbol, one serif line, one sentence, at most one button.
/// Left-anchored 48 pt under the title row, so it reads as the same page with nothing in it yet.
struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var symbolColor: Color = .textSecondary
    var button: (title: LocalizedStringKey, kind: CivaButtonStyle.Kind, action: () -> Void)?

    init(
        symbol: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        symbolColor: Color = .textSecondary,
        button: (title: LocalizedStringKey, kind: CivaButtonStyle.Kind, action: () -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.symbolColor = symbolColor
        self.button = button
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(symbolColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Space.m)
            Text(message)
                .foregroundStyle(Color.textSecondary)
                // No vertical fixedSize: asked for its size at a tiny width, it would wrap per
                // letter and demand a huge height, which made the window grow (AI Activity).
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.top, 6)
            if let button {
                Button(button.title, action: button.action)
                    .buttonStyle(CivaButtonStyle(button.kind, size: .large))
                    .padding(.top, Space.l)
            }
        }
        .padding(.top, Space.xxxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EmptyStateView(
                symbol: "tray",
                title: "No applications yet",
                message: "Track each job you apply for, with the resume you sent.",
                button: ("Add Application", .primary, {})
            )
            EmptyStateView(
                symbol: "sparkles",
                title: "No suggestions",
                message: "Claude's suggestions show up here for you to review.",
                symbolColor: .claude
            )
        }
        .padding(Space.xl)
        .frame(width: 600)
        .background(Color.canvas)
    }
}

#Preview { EmptyPreview() }

#Preview("Dark") { EmptyPreview().preferredColorScheme(.dark) }
