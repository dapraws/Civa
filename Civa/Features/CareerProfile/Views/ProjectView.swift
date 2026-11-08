//
//  ProjectView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

struct ProjectList: View {
    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Project"),
            empty: .init(
                title: String(localized: "No Projects Yet"),
                message: String(localized: "Add personal, academic, or work projects."),
                systemImage: "hammer"
            ),
            order: { recency($0) > recency($1) },
            subtitle: { project in
                [project.role, YearMonth.rangeText(start: project.start, end: project.end)]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            },
            makeRecord: { Project(name: "") },
            editor: { ProjectForm(editor: $0) }
        )
    }

    private func recency(_ project: Project) -> YearMonth {
        YearMonth.recency(start: project.start, end: project.end)
    }
}

struct ProjectForm: View {
    let editor: RecordEditor<Project>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            ClaudeRecordProposalsSection(editor: editor)
            Section {
                TextField("Name", text: editor.binding(\.name), prompt: Text("Required"))
                FieldError(editor.error(for: \.name))
                TextField("Your Role", text: editor.binding(\.role), prompt: Text("Lead Developer"))
            }
            Section {
                ProofField(editor: editor, title: "Live Link", link: \.url)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository")
                    TextField("Repository", text: editor.binding(\.repositoryURL), prompt: Text("https://github.com/…"))
                        .labelsHidden()
                }
                FieldError(editor.error(for: \.repositoryURL))
            } header: {
                Text("Links")
            } footer: {
                Text("With a link or an attached document, this project shows a Verified seal.")
            }
            Section("Dates") {
                YearMonthField(title: String(localized: "Start"), value: editor.binding(\.start))
                YearMonthField(title: String(localized: "End"), value: editor.binding(\.end), emptyTitle: String(localized: "Ongoing"))
                FieldError(editor.error(for: \.end))
            }
            Section {
                TextField(
                    "Description",
                    text: editor.binding(\.details),
                    prompt: Text("What the project is and what you built"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(4...12)
            } header: {
                Text("Description")
            } footer: {
                Text("Background on the project. Claude reads it for context. On a resume it becomes the bullet only when there are no Impact lines.")
            }
            Section {
                StringListEditor(
                    items: editor.binding(\.impacts),
                    prompt: String(localized: "Result of your work"),
                    addTitle: String(localized: "Add Impact")
                )
            } header: {
                HStack(alignment: .center) {
                    Text("Impact")
                    Spacer()
                    AskClaudeButton(
                        title: "Improve with Claude",
                        ask: .init(kind: .improveBullets, category: .projects, targetID: editor.record.id, targetTitle: editor.record.displayTitle),
                        unavailable: improveUnavailable,
                        tip: .improve,
                        showsReason: false,
                        saveFirst: editor.saveIfNeeded
                    )
                }
            } footer: {
                ClaudeUnavailableNote(reason: improveUnavailable)
                Text("Results of the project, like users reached or time saved.")
            }
            Section("Skills") {
                SkillLinksField(editor: editor, skills: \.skills)
            }
            DocumentsSection(editor: editor)
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }

    private var improveUnavailable: String? {
        ClaudeAsk.unavailable(
            needsReview: editor.record.needsReview,
            missing: editor.record.impacts.allSatisfy(\.isBlank) ? String(localized: "Add an impact first, then Claude can improve it.") : nil
        )
    }
}

#Preview("List") {
    NavigationStack {
        ProjectList()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    ProjectForm(editor: .preview())
        .frame(width: 600, height: 800)
        .previewEnvironment()
}
