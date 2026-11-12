//
//  CivaProgressBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// A thin cobalt bar with its value always in words (DESIGN.md §7.14).
struct CivaProgressBar: View {
    let value: Double
    let label: String

    init(value: Double, label: String) {
        self.value = value
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5).fill(Color.selectionFill)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.accent)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 5)
            Text(label)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

private struct ProgressPreview: View {
    var body: some View {
        VStack(spacing: Space.l) {
            CivaProgressBar(value: 5.0 / 6, label: "5 of 6 sections")
            CivaProgressBar(value: 0, label: "0 of 6 sections")
        }
        .frame(width: 240)
        .padding()
        .background(Color.canvas)
    }
}

#Preview { ProgressPreview() }

#Preview("Dark") { ProgressPreview().preferredColorScheme(.dark) }
