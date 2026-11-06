//
//  ResumeItemForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Fields for whatever is selected in the outline. These are the resume's own copies; editing
/// them never touches the Career Profile (FR-034).
struct ResumeItemForm: View {
    let editor: RecordEditor<Resume>
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Binding var document: ResumeDocument
    @Binding var selection: ResumeOutlineItem?

    var body: some View {
        Form {
            if editor.error(for: \.title) != nil, selection != .info {
                Section {
                    FieldError(editor.error(for: \.title))
                    Button("Open Resume Info") { selection = .info }
                }
            }
            switch selection {
            case .info:
                infoFields
            case .header:
                headerFields
            case .summary:
                summaryField
            case .section(let id):
                if let section = sectionBinding(id) {
                    SectionFields(section: section, selection: $selection) {
                        selection = .header
                        document.sections.removeAll { $0.id == id }
                    }
                }
            case .entry(let id):
                if let position = document.entryPosition(id), let entry = entryBinding(id) {
                    let section = document.sections[position.section]
                    EntryFields(entry: entry, kind: section.kind) {
                        selection = .section(section.id)
                        document.sections[position.section].entries.removeAll { $0.id == id }
                    }
                }
            case nil:
                Text("Select an item in the outline.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var infoFields: some View {
        Group {
            Section {
                TextField("Resume Name", text: editor.binding(\.title), prompt: Text("Required"))
                FieldError(editor.error(for: \.title))
                TextField("Target Position", text: editor.binding(\.targetPosition), prompt: Text("iOS Developer"))
            } header: {
                Text("Resume Info")
            } footer: {
                Text("Only you see these. They don't appear on the resume.")
            }
            Section("Job Description") {
                TextField(
                    "Job Description",
                    text: editor.binding(\.jobDescription),
                    prompt: Text("Paste the job description for this version"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(6...20)
            }
            if !editor.record.applications.isEmpty {
                Section {
                    ForEach(editor.record.applications.sorted { $0.company < $1.company }) { application in
                        Button {
                            changes.perform {
                                navigation.recordToOpen = application.id
                                navigation.section = .applications
                            }
                        } label: {
                            Label {
                                Text("\(application.position) · \(application.company)")
                            } icon: {
                                OrganizationLogo(name: application.company, size: 18)
                            }
                        }
                        .buttonStyle(.link)
                    }
                } header: {
                    Text("Sent With")
                } footer: {
                    Text("Applications that use this resume. Link one from the application.")
                }
            }
        }
    }

    private var headerFields: some View {
        Section("Header") {
            TextField("Full Name", text: $document.header.fullName)
            TextField("Headline", text: $document.header.headline, prompt: Text("iOS Engineer"))
            TextField("Email", text: $document.header.email, prompt: Text("name@example.com"))
            TextField("Phone", text: $document.header.phone)
            TextField("Location", text: $document.header.location, prompt: Text("City, Country"))
            PairListEditor(
                items: $document.header.links,
                first: \.label,
                second: \.url,
                prompts: (String(localized: "Label"), String(localized: "URL")),
                addTitle: String(localized: "Add Link"),
                makeItem: { ProfileLink(label: "", url: "") }
            )
        }
    }

    private var summaryField: some View {
        Section {
            TextField(
                "Summary",
                text: $document.summary,
                prompt: Text("Two or three sentences about your experience and focus"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(3...12)
        } header: {
            Text("Summary")
        } footer: {
            Text("Appears under your name without a heading. Leave it empty if you don't need one.")
        }
    }

    // Bindings by id, not index: a row removed mid-update must not crash a field still reading it.
    private func sectionBinding(_ id: UUID) -> Binding<ResumeSection>? {
        guard let current = document.sections.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { document.sections.first { $0.id == id } ?? current },
            set: { new in
                if let index = document.sections.firstIndex(where: { $0.id == id }) { document.sections[index] = new }
            }
        )
    }

    private func entryBinding(_ id: UUID) -> Binding<ResumeEntry>? {
        guard let position = document.entryPosition(id) else { return nil }
        let current = document.sections[position.section].entries[position.entry]
        return Binding(
            get: { document.entryPosition(id).map { document.sections[$0.section].entries[$0.entry] } ?? current },
            set: { new in
                if let p = document.entryPosition(id) { document.sections[p.section].entries[p.entry] = new }
            }
        )
    }
}

/// A section: its entries to jump to, adding one, and removing the section.
private struct SectionFields: View {
    @Binding var section: ResumeSection
    @Binding var selection: ResumeOutlineItem?
    let onRemove: () -> Void

    var body: some View {
        Section {
            ForEach(section.entries) { entry in
                Button(entry.title.isBlank ? section.kind.newEntryTitle : entry.title) {
                    selection = .entry(entry.id)
                }
                .buttonStyle(.link)
            }
            AddButton(title: section.kind.addTitle) {
                let entry = ResumeEntry()
                section.entries.append(entry)
                selection = .entry(entry.id)
            }
        } header: {
            Text(section.kind.heading)
        } footer: {
            Text("Drag sections and entries in the outline to reorder them.")
        }
        Section {
            Button("Remove Section", role: .destructive, action: onRemove)
        }
    }
}

private struct EntryFields: View {
    @Binding var entry: ResumeEntry
    let kind: ResumeSection.Kind
    let onDelete: () -> Void

    var body: some View {
        Section(kind.heading) {
            TextField(kind.titleLabel, text: $entry.title, prompt: Text(kind.titlePrompt))
            TextField(kind.subtitleLabel, text: $entry.subtitle, prompt: Text(kind.subtitlePrompt))
            if kind != .skills {
                TextField("Dates", text: $entry.dates, prompt: Text("Mar 2024 – Present"))
            }
        }
        if kind != .skills {
            Section("Bullet Points") {
                StringListEditor(
                    items: $entry.bullets,
                    prompt: String(localized: "What you did and the result"),
                    addTitle: String(localized: "Add Bullet Point")
                )
            }
        }
        Section {
            Button("Delete Entry", role: .destructive, action: onDelete)
        }
    }
}

/// Labels and titles that say what each section actually holds.
extension ResumeSection.Kind {
    var systemImage: String {
        switch self {
        case .experience: "briefcase"
        case .organizational: "person.3"
        case .education: "graduationcap"
        case .projects: "hammer"
        case .achievements: "trophy"
        case .certifications: "checkmark.seal"
        case .skills: "star"
        }
    }

    var titleLabel: String {
        switch self {
        case .experience, .organizational: String(localized: "Role")
        case .education: String(localized: "Degree")
        case .projects: String(localized: "Project")
        case .achievements: String(localized: "Award")
        case .certifications: String(localized: "Certificate")
        case .skills: String(localized: "Category")
        }
    }

    var titlePrompt: String {
        switch self {
        case .experience: String(localized: "iOS Engineer")
        case .organizational: String(localized: "Event Lead")
        case .education: String(localized: "Bachelor of Computer Science")
        case .projects: String(localized: "Project name")
        case .achievements: String(localized: "Best Pitching Team")
        case .certifications: String(localized: "AWS Cloud Practitioner")
        case .skills: String(localized: "Languages (optional)")
        }
    }

    var subtitleLabel: String {
        switch self {
        case .experience: String(localized: "Company")
        case .organizational: String(localized: "Organization")
        case .education: String(localized: "School")
        case .projects: String(localized: "Your Role")
        case .achievements: String(localized: "Given By")
        case .certifications: String(localized: "Issuer")
        case .skills: String(localized: "Skills")
        }
    }

    var subtitlePrompt: String {
        switch self {
        case .experience, .organizational: String(localized: "Acme · Jakarta")
        case .education: String(localized: "Universitas Indonesia · Depok")
        case .projects: String(localized: "Lead Developer · link")
        case .achievements: String(localized: "Organizer")
        case .certifications: String(localized: "Amazon Web Services")
        case .skills: String(localized: "Swift, Kotlin, Python")
        }
    }

    var addTitle: String {
        switch self {
        case .experience: String(localized: "Add Experience")
        case .organizational: String(localized: "Add Organization")
        case .education: String(localized: "Add Education")
        case .projects: String(localized: "Add Project")
        case .achievements: String(localized: "Add Achievement")
        case .certifications: String(localized: "Add Certification")
        case .skills: String(localized: "Add Skill Line")
        }
    }

    var newEntryTitle: String {
        switch self {
        case .experience: String(localized: "New Experience")
        case .organizational: String(localized: "New Organization")
        case .education: String(localized: "New Education")
        case .projects: String(localized: "New Project")
        case .achievements: String(localized: "New Achievement")
        case .certifications: String(localized: "New Certification")
        case .skills: String(localized: "New Skill Line")
        }
    }
}

#Preview {
    @Previewable @State var selection: ResumeOutlineItem? = .header
    let editor = RecordEditor<Resume>.preview()
    ResumeItemForm(editor: editor, document: editor.binding(\.document), selection: $selection)
        .frame(width: 420, height: 600)
        .previewEnvironment()
}
