//
//  CivaTipViewStyle.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI
import TipKit

/// Inline TipKit tips in Civa's card look (DESIGN.md §7.15). Popover tips keep system styling.
/// Civa's tips have no actions, so none are drawn.
struct CivaTipViewStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            configuration.image?
                .foregroundStyle(Color.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                configuration.title
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.textPrimary)
                configuration.message?
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Close", systemImage: "xmark") {
                configuration.tip.invalidate(reason: .tipClosed)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(Color.textSecondary)
            .frame(width: Size.minTarget, height: Size.minTarget)
            .contentShape(.rect)
            .help("Close")
        }
        .padding(Space.m)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
    }
}

private struct PreviewTip: Tip {
    var title: Text { Text("Hide a line without deleting it") }
    var message: Text? { Text("The eye keeps the entry in your profile but leaves it off this resume.") }
    var image: Image? { Image(systemName: "eye") }
}

#Preview {
    TipView(PreviewTip())
        .tipViewStyle(CivaTipViewStyle())
        .frame(width: 420)
        .padding()
        .background(Color.canvas)
}

#Preview("Dark") {
    TipView(PreviewTip())
        .tipViewStyle(CivaTipViewStyle())
        .frame(width: 420)
        .padding()
        .background(Color.canvas)
        .preferredColorScheme(.dark)
}
