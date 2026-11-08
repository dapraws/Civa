//
//  SkillView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Skills by category: the categories the user named down the left; the selected category's
/// skills as chips on the right, with the chosen skill's details below.
/// Dragging a chip onto a category moves it there. Selecting and adding go through the
/// unsaved-changes guard, as on the other record pages.
struct SkillList: View {
    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \Skill.name) private var skills: [Skill]
    @State private var group: SkillGroup?
    @State private var editor: RecordEditor<Skill>?
    @State private var moveError: String?

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addSkill) {
                        Label("Add Skill", systemImage: "plus")
                    }
                    .keyboardShortcut("n")
                    .help("Add Skill (⌘N)")
                }
            }
            .onAppear {
                if navigation.startsNewRecord {
                    navigation.startsNewRecord = false
                    addSkill()
                } else if let target = navigation.recordToOpen, let skill = skills.first(where: { AnyHashable($0.id) == target }) {
                    navigation.recordToOpen = nil
                    open(skill)
                } else if group == nil {
                    // Like the other lists, open on the first item.
                    select(groups.first)
                }
            }
            .onChange(of: navigation.recordToOpen) { _, target in
                guard let target, let skill = skills.first(where: { AnyHashable($0.id) == target }) else { return }
                navigation.recordToOpen = nil
                open(skill)
            }
            // After a save, follow the skill to its category.
            .onChange(of: editor?.isDirty) { _, isDirty in
                if isDirty == false, let skill = editor?.record, !(editor?.isNew ?? true) { group = SkillGroup(skill) }
            }
            .alert("Couldn't Move the Skill", isPresented: Binding(get: { moveError != nil }, set: { if !$0 { moveError = nil } })) {
                Button("OK") { moveError = nil }
            } message: {
                Text(moveError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if skills.isEmpty && editor == nil {
            ContentUnavailableView {
                Label("No Skills Yet", systemImage: "star")
            } description: {
                Text("Add skills here, or link them from an experience or project.")
            } actions: {
                Button("Add Skill", action: addSkill)
            }
        } else {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 220)
                Divider()
                VStack(spacing: 0) {
                    chips
                    Divider()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: Binding(get: { group }, set: { new in changes.perform { select(new) } })) {
            Section("Categories") {
                ForEach(groups, id: \.self) { row in
                    sidebarRow(row)
                        .tag(row)
                        .dropDestination(for: String.self) { ids, _ in move(ids, to: row) }
                }
            }
        }
    }

    private func sidebarRow(_ row: SkillGroup) -> some View {
        let members = skills(in: row)
        return HStack {
            Text(row.title)
                .foregroundStyle(row.category.isBlank ? .secondary : .primary)
            if members.contains(where: \.needsReview) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("Some of these need review")
            }
            Spacer()
            Text(members.count, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Chips

    private var chips: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group?.title ?? String(localized: "Skills"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Add Skill", systemImage: "plus", action: addSkill)
            }
            ScrollView {
                FlowLayout(spacing: 6, rowSpacing: 6) {
                    ForEach(group.map(skills(in:)) ?? []) { skill in
                        Button {
                            changes.perform { open(skill) }
                        } label: {
                            SkillChip(skill: skill, isSelected: editor?.record.id == skill.id)
                        }
                        .buttonStyle(.plain)
                        .draggable(skill.id.uuidString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .fixedSize(horizontal: false, vertical: true)
            Text("Drag a skill onto a category to move it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let editor {
            SkillForm(editor: editor)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    RecordEditorBar(editor: editor, onClose: close)
                }
                .startsWithoutFocus(!editor.isNew)
                .id(editor.record.id)
        } else {
            ContentUnavailableView("No Skill Selected", systemImage: "star", description: Text("Select a skill to see its details."))
        }
    }

    // MARK: Data

    /// Every category in use, plus the one being shown even if it's now empty.
    private var groups: [SkillGroup] {
        var all = Set(skills.map(SkillGroup.init))
        if let group { all.insert(group) }
        return all.sorted()
    }

    private func skills(in group: SkillGroup) -> [Skill] {
        skills.filter { SkillGroup($0) == group }
    }

    private func select(_ new: SkillGroup?) {
        group = new
        if let first = new.map(skills(in:))?.first { open(first) } else { close() }
    }

    private func open(_ skill: Skill) {
        group = SkillGroup(skill)
        editor = RecordEditor(record: skill, context: context)
        changes.active = editor
    }

    private func addSkill() {
        changes.perform {
            let skill = Skill(name: "", category: group?.category ?? "")
            let editor = RecordEditor(creating: skill, in: context)
            self.editor = editor
            changes.active = editor
        }
    }

    private func close() {
        editor = nil
        changes.active = nil
    }

    /// Moves dragged skills into a category. Unsaved edits are resolved first.
    private func move(_ ids: [String], to target: SkillGroup) -> Bool {
        let moving = skills.filter { ids.contains($0.id.uuidString) }
        guard !moving.isEmpty else { return false }
        changes.perform {
            for skill in moving {
                skill.category = target.category
                skill.updatedAt = .now
            }
            do {
                try context.save()
            } catch {
                context.rollback()
                moveError = error.localizedDescription
            }
        }
        return true
    }
}

/// A sidebar row: one category. Categories match ignoring case and surrounding spaces.
struct SkillGroup: Hashable, Comparable {
    let category: String

    init(category: String) {
        self.category = category.trimmingCharacters(in: .whitespaces)
    }

    init(_ skill: Skill) {
        self.init(category: skill.category)
    }

    var title: String { category.isBlank ? String(localized: "No Category") : category }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category.lowercased() == rhs.category.lowercased()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(category.lowercased())
    }

    /// Alphabetically, with "No Category" last.
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category.isBlank != rhs.category.isBlank { return rhs.category.isBlank }
        return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
    }

    /// Offered in the Category field next to the ones already in use.
    static let starters = [
        String(localized: "Hard Skills"), String(localized: "Soft Skills"),
        String(localized: "Languages"), String(localized: "Tools"),
    ]
}

struct SkillForm: View {
    let editor: RecordEditor<Skill>
    @Query(sort: \Skill.category) private var skills: [Skill]

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Name", text: editor.binding(\.name), prompt: Text("Required"))
                FieldError(editor.error(for: \.name))
                TextField("Category", text: editor.binding(\.category), prompt: Text("Hard Skills, Soft Skills, Tools"))
                    .textInputSuggestions {
                        ForEach(categorySuggestions, id: \.self) { Text($0).textInputCompletion($0) }
                    }
            } footer: {
                Text("Name categories however you like. Skills in the same category are listed together, on this page and on your resumes.")
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

    /// Categories in use plus a few starters, narrowed to what's typed.
    private var categorySuggestions: [String] {
        let typed = editor.record.category.trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        return (skills.map { $0.category.trimmingCharacters(in: .whitespaces) } + SkillGroup.starters).filter { name in
            !name.isEmpty && name.caseInsensitiveCompare(typed) != .orderedSame
                && (typed.isEmpty || name.localizedCaseInsensitiveContains(typed)) && seen.insert(name.lowercased()).inserted
        }
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
