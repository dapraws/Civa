//
//  CivaForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

extension View {
    /// A grouped `Form` in Civa's frame: `canvas` behind it and, for pages, left-anchored at the
    /// form width (DESIGN.md §5.2, §7.6). The system form keeps label/field layout, keyboard and
    /// accessibility; it doesn't allow white rows, so they keep the system's soft fill.
    /// Pass `maxWidth: nil` in sheets and panes that should fill their space.
    func civaForm(maxWidth: CGFloat? = Size.formMaxWidth) -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            // The grouped form insets its sections about 20 pt on each side.
            .frame(maxWidth: maxWidth.map { $0 + 40 } ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.canvas)
    }
}

/// A section heading in Young Serif (`sectionTitle`), read as a heading by VoiceOver.
struct SectionTitle: View {
    private let text: Text

    init(_ title: LocalizedStringKey) {
        text = Text(title)
    }

    init<S: StringProtocol>(_ title: S) {
        text = Text(title)
    }

    var body: some View {
        text
            .font(.sectionTitle)
            .foregroundStyle(Color.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

extension Section where Parent == SectionTitle, Footer == EmptyView, Content: View {
    /// `Section("Contact") { … }` with a serif heading.
    init(civa title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { SectionTitle(title) })
    }
}

#Preview {
    Form {
        Section(civa: "Contact") {
            TextField("Email", text: .constant("darrel@example.com"))
            TextField("Phone", text: .constant("+62 812 0000 0000"))
        }
        Section {
            Toggle("Fetch Logos Online", isOn: .constant(true))
        } header: {
            SectionTitle("Logos")
        } footer: {
            Text("Only the names you type are sent.")
        }
    }
    .civaForm()
    .frame(width: 900, height: 400)
}

#Preview("Dark") {
    Form {
        Section(civa: "Contact") {
            TextField("Email", text: .constant("darrel@example.com"))
        }
    }
    .civaForm()
    .frame(width: 900, height: 300)
    .preferredColorScheme(.dark)
}
