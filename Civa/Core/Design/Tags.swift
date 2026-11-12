//
//  Tags.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// The three tags Civa has (DESIGN.md §7.11). No others.
enum CivaTagKind {
    case claude, needsReview, master
}

struct CivaTag: View {
    let kind: CivaTagKind
    var title: LocalizedStringKey?

    init(_ kind: CivaTagKind, title: LocalizedStringKey? = nil) {
        self.kind = kind
        self.title = title
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            if kind == .claude {
                Image(systemName: "sparkles").accessibilityHidden(true)
            }
            Text(title ?? defaultTitle)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(background, in: .rect(cornerRadius: Radius.tag))
    }

    private var defaultTitle: LocalizedStringKey {
        switch kind {
        case .claude: "Claude"
        case .needsReview: "Needs Review"
        case .master: "Master"
        }
    }

    private var foreground: Color {
        switch kind {
        case .claude: .claudeText
        case .needsReview: .accentText
        case .master: .textPrimary
        }
    }

    private var background: Color {
        switch kind {
        case .claude: .claudeTint
        case .needsReview: .accentTint
        case .master: .selectionFill
        }
    }
}

private struct TagsPreview: View {
    var body: some View {
        HStack(spacing: Space.s) {
            CivaTag(.claude)
            CivaTag(.needsReview)
            CivaTag(.master)
        }
        .padding()
        .background(Color.canvas)
    }
}

#Preview { TagsPreview() }

#Preview("Dark") { TagsPreview().preferredColorScheme(.dark) }
