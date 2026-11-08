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
/// `accessory` adds a control to each row, such as an eye.
struct PairListEditor<Item: Identifiable & Equatable, Accessory: View>: View {
    @Binding var items: [Item]
    let first: WritableKeyPath<Item, String>
    let second: WritableKeyPath<Item, String>
    let prompts: (first: String, second: String)
    let addTitle: String
    let makeItem: () -> Item
    @ViewBuilder var accessory: (Item) -> Accessory

    var body: some View {
        ForEach($items) { $item in
            HStack {
                TextField(prompts.first, text: $item[dynamicMember: first], prompt: Text(prompts.first))
                TextField(prompts.second, text: $item[dynamicMember: second], prompt: Text(prompts.second))
                accessory(item)
                RemoveButton { items.removeAll { $0.id == item.id } }
            }
            .labelsHidden()
        }
        AddButton(title: addTitle) { items.append(makeItem()) }
    }
}

extension PairListEditor where Accessory == EmptyView {
    init(
        items: Binding<[Item]>, first: WritableKeyPath<Item, String>, second: WritableKeyPath<Item, String>,
        prompts: (first: String, second: String), addTitle: String, makeItem: @escaping () -> Item
    ) {
        self.init(items: items, first: first, second: second, prompts: prompts, addTitle: addTitle, makeItem: makeItem) { _ in EmptyView() }
    }
}

/// A dropdown for an optional choice stored as its raw value; empty is Not Set.
struct OptionPicker<Option: TitledOption>: View {
    let title: LocalizedStringKey
    @Binding var selection: String
    let options: [Option]

    init(_ title: LocalizedStringKey, selection: Binding<String>, options: [Option]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not Set").tag("")
            Divider()
            ForEach(options) { Text($0.title).tag($0.rawValue) }
        }
    }
}

struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Remove", systemImage: "minus.circle")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}

struct AddButton: View {
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
