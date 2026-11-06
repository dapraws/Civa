//
//  PersonalInfoView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// There's one personal record, so this tab is a form without a list.
struct PersonalInfoView: View {
    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Query private var records: [PersonalInfo]
    @State private var editor: RecordEditor<PersonalInfo>?

    var body: some View {
        if let editor {
            PersonalInfoForm(editor: editor)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    RecordEditorBar(editor: editor, canDelete: false, onClose: startEditing)
                }
        } else {
            // An empty view never appears, so give onAppear something to attach to.
            Color.clear.onAppear(perform: startEditing)
        }
    }

    /// Edits the saved record, or starts a new one when none is saved yet.
    private func startEditing() {
        let editor = records.first.map { RecordEditor(record: $0, context: context) }
            ?? RecordEditor(creating: PersonalInfo(fullName: ""), in: context)
        self.editor = editor
        changes.active = editor
    }
}

struct PersonalInfoForm: View {
    let editor: RecordEditor<PersonalInfo>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Full Name", text: editor.binding(\.fullName), prompt: Text("Required"))
                FieldError(editor.error(for: \.fullName))
                TextField("Headline", text: editor.binding(\.headline), prompt: Text("iOS Engineer"))
            }
            Section("Contact") {
                TextField("Email", text: editor.binding(\.email), prompt: Text("name@example.com"))
                FieldError(editor.error(for: \.email))
                TextField("Phone", text: editor.binding(\.phone))
                TextField("Location", text: editor.binding(\.location), prompt: Text("City, Country"))
            }
            Section("Links") {
                PairListEditor(
                    items: editor.binding(\.links),
                    first: \.label,
                    second: \.url,
                    prompts: (String(localized: "Label"), String(localized: "URL")),
                    addTitle: String(localized: "Add Link"),
                    makeItem: { ProfileLink(label: "", url: "") }
                )
            }
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }
}

#Preview("Tab") {
    PersonalInfoView()
        .frame(width: 700, height: 600)
        .previewEnvironment()
}

#Preview("Form") {
    PersonalInfoForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
