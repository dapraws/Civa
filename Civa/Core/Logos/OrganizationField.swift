//
//  OrganizationField.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// A company or school name field that suggests matching brands as you type. When the name
/// matches a suggestion, its website is remembered so the logo shows wherever the name appears.
struct OrganizationField: View {
    let title: LocalizedStringKey
    @Binding var name: String
    var prompt: Text?

    @Environment(\.modelContext) private var context
    @AppStorage(Brandfetch.fetchesLogosKey) private var fetchesLogos = true
    /// Live results only; Brandfetch's terms don't allow keeping them.
    @State private var brands: [Brandfetch.Brand] = []

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, text: $name, prompt: prompt)
                    .labelsHidden()
                    .textInputSuggestions {
                        ForEach(brands) { brand in
                            Label {
                                Text(brand.title)
                                Text(brand.domain)
                            } icon: {
                                AsyncImage(url: brand.icon) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                                    .frame(width: 16, height: 16)
                            }
                            .textInputCompletion(brand.title)
                        }
                    }
                OrganizationLogo(name: name, size: 22)
                    .contextMenu {
                        Button("Remove Logo", action: forget)
                    }
            }
        }
        .task(id: name) { await search() }
        .onChange(of: name) { remember() }
    }

    private func search() async {
        guard fetchesLogos, Brandfetch.clientID != nil, name.trimmingCharacters(in: .whitespaces).count >= 2 else {
            brands = []
            return
        }
        // Debounce: typing again cancels this task before the request goes out.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        brands = (try? await Brandfetch.search(name)) ?? []
        remember()
    }

    /// Saved with the record it's typed into, and rolled back with it.
    private func remember() {
        let key = Organization.key(for: name)
        guard let brand = brands.first(where: { Organization.key(for: $0.title) == key }),
              existing(key) == nil
        else { return }
        context.insert(Organization(name: name, domain: brand.domain))
    }

    private func forget() {
        if let organization = existing(Organization.key(for: name)) { context.delete(organization) }
    }

    private func existing(_ key: String) -> Organization? {
        try? context.fetch(FetchDescriptor<Organization>(predicate: #Predicate { $0.key == key })).first
    }
}

#Preview {
    @Previewable @State var name = "Apple"
    Form {
        OrganizationField(title: "Company", name: $name, prompt: Text("Required"))
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .previewEnvironment()
}
