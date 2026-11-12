//
//  StatusMark.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

extension ApplicationStatus {
    /// DESIGN.md §3.4. Only the dot carries color, so the word always passes contrast.
    var color: Color {
        switch self {
        case .wishlist, .withdrawn: .statusNeutral
        case .applied: .accentText
        case .assessment, .interview: .statusAmber
        case .offer: .statusGreen
        case .rejected: .statusRed
        }
    }
}

/// A 7 pt dot in the status color, then the status word (DESIGN.md §7.10). VoiceOver reads the word.
struct StatusMark: View {
    let status: ApplicationStatus
    var emphasized = false

    init(_ status: ApplicationStatus, emphasized: Bool = false) {
        self.status = status
        self.emphasized = emphasized
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(status.title)
                .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
        }
    }
}

private struct StatusMarkPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach([Color.canvas, Color.selectionFill], id: \.self) { background in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ApplicationStatus.allCases) { StatusMark($0) }
                    StatusMark(.offer, emphasized: true)
                }
                .padding(12)
                .background(background)
            }
        }
        .padding()
        .background(Color.canvas)
    }
}

#Preview { StatusMarkPreview() }

#Preview("Dark") { StatusMarkPreview().preferredColorScheme(.dark) }
