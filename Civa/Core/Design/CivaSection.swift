//
//  CivaSection.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// A grouped section (DESIGN.md §7.6): an optional serif heading, a white container with a
/// hairline outline, rows divided by inset hairlines, and an optional footer note.
struct CivaSection<Content: View>: View {
    let title: LocalizedStringKey?
    let footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Space.s)
            }
            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, Space.m)
                        }
                        row
                    }
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Radius.card))
            .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 6)
            }
        }
    }
}

/// A row in a `CivaSection`: label leading, value trailing. `stacked` puts the label above, for
/// long values such as URLs and the headline.
struct CivaRow<Value: View>: View {
    let label: LocalizedStringKey
    var stacked = false
    @ViewBuilder let value: Value

    init(_ label: LocalizedStringKey, stacked: Bool = false, @ViewBuilder value: () -> Value) {
        self.label = label
        self.stacked = stacked
        self.value = value()
    }

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).foregroundStyle(Color.textSecondary)
                    value
                }
                .padding(.vertical, Space.s)
            } else {
                HStack(spacing: Space.l) {
                    Text(label).foregroundStyle(Color.textSecondary)
                    Spacer(minLength: 0)
                    value
                }
            }
        }
        .padding(.horizontal, Space.m)
        .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
    }
}

private struct SectionPreview: View {
    @State private var website = "https://darrel.dev"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            CivaSection("Contact", footer: "Shown at the top of every resume.") {
                CivaRow("Email") { Text("darrel@example.com") }
                CivaRow("Phone") { Text("+62 812 0000 0000") }
                CivaRow("Website", stacked: true) {
                    TextField("Website", text: $website).textFieldStyle(.civa)
                }
            }
            CivaSection {
                CivaRow("Fetch Logos Online") { Toggle("", isOn: .constant(true)).labelsHidden() }
            }
        }
        .frame(width: 480)
        .padding()
        .background(Color.canvas)
    }
}

#Preview { SectionPreview() }

#Preview("Dark") { SectionPreview().preferredColorScheme(.dark) }
