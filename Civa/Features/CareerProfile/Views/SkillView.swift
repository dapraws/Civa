//
//  SkillView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

struct SkillList: View {
    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Skill"),
            empty: .init(
                title: String(localized: "No Skills Yet"),
                message: String(localized: "Add skills here, or link them from an experience or project."),
                systemImage: "star"
            ),
            order: { sortKey($0) < sortKey($1) },
            subtitle: { skill in
                [skill.type?.title ?? "", skill.category].filter { !$0.isEmpty }.joined(separator: " · ")
            },
            makeRecord: { Skill(name: "") },
            editor: { SkillForm(editor: $0) }
        )
    }

    /// Alphabetical, with a new (unnamed) skill on top.
    private func sortKey(_ skill: Skill) -> String {
        skill.name.isBlank ? "" : skill.name.lowercased()
    }
}

struct SkillForm: View {
    let editor: RecordEditor<Skill>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Name", text: editor.binding(\.name), prompt: Text("Required"))
                FieldError(editor.error(for: \.name))
                OptionPicker("Type", selection: editor.binding(\.typeRaw), options: SkillType.allCases)
                TextField("Category", text: editor.binding(\.category), prompt: Text("Languages, Tools, Design"))
            }
            Section {
                TextField("Proficiency", text: proficiency, prompt: Text("Optional"))
            } footer: {
                Text("Leave this empty if you'd rather not rate yourself.")
            }
            Section {
                let evidence = editor.record.experiences.map(\.displayTitle) + editor.record.projects.map(\.displayTitle)
                if evidence.isEmpty {
                    Text("Link this skill from an experience or project to show where you used it.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(evidence.sorted(), id: \.self) { title in
                        Text(title)
                    }
                }
            } header: {
                Text("Used In")
            }
        }
        .formStyle(.grouped)
    }

    /// Stored as nil when empty, since proficiency is optional (FR-014).
    private var proficiency: Binding<String> {
        Binding(
            get: { editor.record.proficiency ?? "" },
            set: { value in editor.update { $0.proficiency = value.isBlank ? nil : value } }
        )
    }
}

#Preview("List") {
    NavigationStack {
        SkillList()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    SkillForm(editor: .preview())
        .frame(width: 600, height: 500)
        .previewEnvironment()
}
