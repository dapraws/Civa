//
//  SkillLinksField.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Links skills to an experience or project as evidence (FR-014). Typing a name that already
/// exists links that skill (ignoring case); a new name creates it. Removing only unlinks.
struct SkillLinksField<Model: EditableRecord>: View {
    let editor: RecordEditor<Model>
    let skills: ReferenceWritableKeyPath<Model, [Skill]>

    @Environment(\.modelContext) private var context
    @Query(sort: \Skill.name) private var allSkills: [Skill]
    @State private var newName = ""

    var body: some View {
        let linked = editor.record[keyPath: skills].sorted { $0.name < $1.name }
        if !linked.isEmpty {
            FlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(linked) { skill in
                    SkillChip(skill: skill) { unlink(skill) }
                }
            }
            .padding(.vertical, 2)
        }
        TextField("Add Skill", text: $newName, prompt: Text("Type a skill and press Return"))
            .onSubmit(link)
            .textInputSuggestions {
                ForEach(suggestions(excluding: linked)) { skill in
                    Text(skill.name).textInputCompletion(skill.name)
                }
            }
    }

    private func suggestions(excluding linked: [Skill]) -> [Skill] {
        let query = newName.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return allSkills.filter { skill in
            !linked.contains(skill) && skill.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func link() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let skill = allSkills.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? {
            let skill = Skill(name: name)
            context.insert(skill)  // saved, or rolled back, with the record being edited
            return skill
        }()
        editor.update { record in
            if !record[keyPath: skills].contains(skill) {
                record[keyPath: skills].append(skill)
            }
        }
        newName = ""
    }

    private func unlink(_ skill: Skill) {
        editor.update { record in
            record[keyPath: skills].removeAll { $0 == skill }
        }
    }
}

/// A skill as a rounded tag. Orange outline while it needs review; × removes it when given.
struct SkillChip: View {
    let skill: Skill
    var isSelected = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            if skill.needsReview {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("Needs review")
            }
            Text(skill.displayTitle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(skill.displayTitle)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.5)), in: Capsule())
        .overlay {
            Capsule().strokeBorder(skill.needsReview ? Color.orange : Color.secondary.opacity(0.35), lineWidth: 0.5)
        }
        .fixedSize()
    }
}

#Preview {
    Form {
        Section("Skills") {
            SkillLinksField(editor: RecordEditor<Experience>.preview(), skills: \.skills)
        }
    }
    .formStyle(.grouped)
    .previewEnvironment()
}
