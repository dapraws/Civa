//
//  RecordRow.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// A list row: title, optional subtitle, the Verified seal when there's proof,
/// and a review badge when the record isn't confirmed.
/// A row in a record list (DESIGN.md §7.8): title, a muted second line, the Needs Review tag,
/// and the sidebar's hover and selection look.
struct RecordRow<Leading: View>: View {
    let title: String
    var subtitle = ""
    var needsReview = false
    var proof: Proof?
    var isSelected = false
    @ViewBuilder var leading: Leading

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Space.s) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    Text(title)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if let proof { ProofSeal(proof: proof) }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if needsReview { ReviewBadge() }
        }
        .padding(.vertical, Space.s)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: Size.listRow, alignment: .leading)
        .background(isSelected ? Color.selectionFill : isHovered ? Color.hover : .clear, in: .rect(cornerRadius: Radius.control))
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5).fill(Color.accent).frame(width: 3, height: 14).padding(.leading, 2)
            }
        }
        .contentShape(.rect(cornerRadius: Radius.control))
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

extension RecordRow where Leading == EmptyView {
    init(title: String, subtitle: String = "", needsReview: Bool = false, proof: Proof? = nil, isSelected: Bool = false) {
        self.init(title: title, subtitle: subtitle, needsReview: needsReview, proof: proof, isSelected: isSelected) { EmptyView() }
    }
}

/// "Needs Review" marker (FR-015): the tag's words carry it, not color alone.
struct ReviewBadge: View {
    var body: some View {
        CivaTag(.needsReview)
    }
}

#Preview {
    VStack(spacing: 1) {
        RecordRow(title: "iOS Engineer", subtitle: "Acme · Mar 2024 – Present", isSelected: true)
        RecordRow(title: "Intern", subtitle: "Globex · 2023", needsReview: true)
    }
    .padding(8)
    .frame(width: 260)
    .background(Color.sidebar)
}

#Preview("Dark") {
    VStack(spacing: 1) {
        RecordRow(title: "iOS Engineer", subtitle: "Acme · Mar 2024 – Present", isSelected: true)
        RecordRow(title: "Intern", subtitle: "Globex · 2023", needsReview: true)
    }
    .padding(8)
    .frame(width: 260)
    .background(Color.sidebar)
    .preferredColorScheme(.dark)
}
