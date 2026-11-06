//
//  ReviewBanner.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Shown at the top of a profile record that hasn't been confirmed (FR-015).
/// Renders nothing for confirmed records.
struct ReviewBanner<Model: ProfileRecord>: View {
    let editor: RecordEditor<Model>

    var body: some View {
        if editor.record.needsReview {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        ReviewBadge()
                        Text("Confirm this information before it's used in a resume.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Confirm") { editor.confirm() }
                }
            }
        }
    }
}

#Preview {
    Form {
        ReviewBanner(editor: RecordEditor<Experience>.preview(needsReview: true))
    }
    .formStyle(.grouped)
    .previewEnvironment()
}
