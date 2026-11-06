//
//  ListEditors.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Editable list of single lines, such as impact statements. Place inside a form section.
struct StringListEditor: View {
    @Binding var items: [String]
    let prompt: String
    let addTitle: String

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack {
                TextField(prompt, text: line(at: index), prompt: Text(prompt), axis: .vertical)
                    .labelsHidden()
                RemoveButton { items.remove(at: index) }
            }
        }
        AddButton(title: addTitle) { items.append("") }
    }

    /// Index-safe while a row is being removed.
    private func line(at index: Int) -> Binding<String> {
        Binding(
            get: { items.indices.contains(index) ? items[index] : "" },
            set: { if items.indices.contains(index) { items[index] = $0 } }
        )
    }
}

/// Editable two-part entries, such as custom fields or links. Place inside a form section.
struct PairListEditor<Item: Identifiable & Equatable>: View {
    @Binding var items: [Item]
    let first: WritableKeyPath<Item, String>
    let second: WritableKeyPath<Item, String>
    let prompts: (first: String, second: String)
    let addTitle: String
    let makeItem: () -> Item

    var body: some View {
        ForEach($items) { $item in
            HStack {
                TextField(prompts.first, text: $item[dynamicMember: first], prompt: Text(prompts.first))
                TextField(prompts.second, text: $item[dynamicMember: second], prompt: Text(prompts.second))
                RemoveButton { items.removeAll { $0.id == item.id } }
            }
            .labelsHidden()
        }
        AddButton(title: addTitle) { items.append(makeItem()) }
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Remove", systemImage: "minus.circle")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}

private struct AddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    @Previewable @State var impacts = ["Cut onboarding time by 30%"]
    @Previewable @State var fields = [CustomField(name: "Team Size", value: "6")]
    Form {
        Section("Impact") {
            StringListEditor(items: $impacts, prompt: "Result of your work", addTitle: "Add Impact")
        }
        Section("Custom Fields") {
            PairListEditor(
                items: $fields,
                first: \.name,
                second: \.value,
                prompts: ("Name", "Value"),
                addTitle: "Add Field",
                makeItem: { CustomField(name: "", value: "") }
            )
        }
    }
    .formStyle(.grouped)
}
