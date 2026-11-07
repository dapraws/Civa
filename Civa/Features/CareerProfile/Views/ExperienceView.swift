//
//  ExperienceView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Professional or Organizational Experience; both are `Experience` records filtered by kind.
struct ExperienceList: View {
    let kind: ExperienceKind

    var body: some View {
        let kindRaw = kind.rawValue
        RecordListDetail(
            addTitle: kind == .professional
                ? String(localized: "Add Experience")
                : String(localized: "Add Organization"),
            empty: kind == .professional
                ? .init(
                    title: String(localized: "No Professional Experience Yet"),
                    message: String(localized: "Add jobs and internships, with what you did and the results."),
                    systemImage: "briefcase"
                )
                : .init(
                    title: String(localized: "No Organizational Experience Yet"),
                    message: String(localized: "Add clubs, communities, and volunteer roles."),
                    systemImage: "person.3"
                ),
            filter: #Predicate<Experience> { $0.kindRaw == kindRaw },
            order: { recency($0) > recency($1) },
            subtitle: { experience in
                [experience.organization, dates(experience)]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            },
            makeRecord: { Experience(kind: kind, organization: "", role: "") },
            editor: { ExperienceForm(editor: $0) }
        )
    }

    private func recency(_ experience: Experience) -> YearMonth {
        YearMonth.recency(start: experience.start, end: experience.end, isCurrent: experience.isCurrent)
    }

    private func dates(_ experience: Experience) -> String {
        YearMonth.rangeText(start: experience.start, end: experience.end, isCurrent: experience.isCurrent)
    }
}

struct ExperienceForm: View {
    let editor: RecordEditor<Experience>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            ClaudeRecordProposalsSection(editor: editor)
            Section {
                TextField("Role", text: editor.binding(\.role), prompt: Text("Required"))
                FieldError(editor.error(for: \.role))
                OrganizationField(
                    title: editor.record.kind == .professional ? "Company" : "Organization",
                    name: editor.binding(\.organization),
                    prompt: Text("Required")
                )
                FieldError(editor.error(for: \.organization))
                if editor.record.kind == .professional {
                    OptionPicker("Employment Type", selection: editor.binding(\.employmentTypeRaw), options: EmploymentType.allCases)
                } else {
                    OptionPicker("Type", selection: editor.binding(\.organizationTypeRaw), options: OrganizationType.allCases)
                }
                TextField("Location", text: editor.binding(\.location), prompt: Text("City, Country"))
                OptionPicker("Work Arrangement", selection: editor.binding(\.workArrangementRaw), options: WorkArrangement.allCases)
                if editor.record.kind == .organizational {
                    TextField("Recognition", text: editor.binding(\.recognition), prompt: Text("Graduate with Distinction"))
                }
            }
            Section("Dates") {
                YearMonthField(title: String(localized: "Start"), value: editor.binding(\.start))
                Toggle(
                    editor.record.kind == .professional
                        ? String(localized: "I currently work here")
                        : String(localized: "I'm currently active here"),
                    isOn: isCurrent
                )
                if !editor.record.isCurrent {
                    YearMonthField(title: String(localized: "End"), value: editor.binding(\.end))
                    FieldError(editor.error(for: \.end))
                }
            }
            Section("Description") {
                TextField(
                    "Description",
                    text: editor.binding(\.details),
                    prompt: Text("What you did and how you did it"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(4...12)
            }
            Section {
                StringListEditor(
                    items: editor.binding(\.impacts),
                    prompt: String(localized: "Result of your work"),
                    addTitle: String(localized: "Add Impact")
                )
                AskClaudeButton(
                    title: "Improve with Claude",
                    ask: .init(kind: .improveBullets, category: .experience, targetID: editor.record.id, targetTitle: editor.record.displayTitle),
                    disabled: editor.isNew || editor.isDirty || editor.record.impacts.allSatisfy(\.isBlank) || editor.record.needsReview
                )
                .buttonStyle(.borderless)
            } header: {
                Text("Impact")
            } footer: {
                Text("Results of your work, like “Cut onboarding time by 30%”. Awards and other formal recognition go in Achievements.")
            }
            Section("Skills") {
                SkillLinksField(editor: editor, skills: \.skills)
            }
            Section {
                ProofField(editor: editor, title: "Proof Link", link: \.proofURL)
            } header: {
                Text("Proof")
            } footer: {
                Text("A certificate, recommendation, or announcement. With a link or an attached document, this record shows a Verified seal.")
            }
            DocumentsSection(editor: editor)
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }

    /// Turning "current" on clears the end date.
    private var isCurrent: Binding<Bool> {
        Binding(
            get: { editor.record.isCurrent },
            set: { value in
                editor.update { experience in
                    experience.isCurrent = value
                    if value { experience.end = nil }
                }
            }
        )
    }
}

#Preview("List") {
    NavigationStack {
        ExperienceList(kind: .professional)
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    ExperienceForm(editor: .preview())
        .frame(width: 600, height: 800)
        .previewEnvironment()
}
