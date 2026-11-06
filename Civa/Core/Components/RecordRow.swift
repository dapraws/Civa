//
//  RecordRow.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// A list row: title, optional subtitle, and a review badge when the record isn't confirmed.
struct RecordRow: View {
    let title: String
    var subtitle = ""
    var needsReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if needsReview {
                ReviewBadge()
            }
        }
        .padding(.vertical, 2)
    }
}

/// "Needs Review" marker (FR-015). Icon and text, so it doesn't rely on color.
struct ReviewBadge: View {
    var body: some View {
        Label("Needs Review", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
    }
}

#Preview {
    List {
        RecordRow(title: "iOS Engineer", subtitle: "Acme · Mar 2024 – Present")
        RecordRow(title: "Intern", subtitle: "Globex · 2023", needsReview: true)
    }
}
