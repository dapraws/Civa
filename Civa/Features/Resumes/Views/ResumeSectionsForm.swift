//
//  ResumeSectionsForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// The whole resume as form cards, top to bottom in the same order as the page (FR-034).
/// These are the resume's own copies; editing them never touches the Career Profile.
struct ResumeSectionsForm: View {
    @Binding var document: ResumeDocument

    var body: some View {
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

        Section {
            TextField(
                "Summary",
                text: $document.summary,
                prompt: Text("Two or three sentences about your experience and focus"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(3...10)
        } header: {
            Text("Summary")
        } footer: {
            Text("Appears under your name without a heading. Leave it empty if you don't need one.")
        }

        ForEach($document.sections) { $section in
            SectionCards(section: $section) {
                document.sections.removeAll { $0.id == section.id }
            }
        }

        let missing = ResumeSection.Kind.allCases.filter { kind in !document.sections.contains { $0.kind == kind } }
        if !missing.isEmpty {
            Section {
                Menu("Add Section") {
                    ForEach(missing, id: \.self) { kind in
                        Button(kind.heading) { document.sections.append(ResumeSection(kind: kind)) }
                    }
                }
                .fixedSize()
            }
        }
    }
}

/// One resume section: a card per entry under the section's heading, then an add button.
private struct SectionCards: View {
    @Binding var section: ResumeSection
    let onRemove: () -> Void

    var body: some View {
        ForEach($section.entries) { $entry in
            Section {
                EntryCard(entry: $entry, kind: section.kind) { action in
                    switch action {
                    case .moveUp: section.entries.move(id: entry.id, by: -1)
                    case .moveDown: section.entries.move(id: entry.id, by: 1)
                    case .delete: section.entries.removeAll { $0.id == entry.id }
                    }
                }
            } header: {
                if entry.id == section.entries.first?.id { heading }
            }
        }
        Section {
            AddButton(title: section.kind.addTitle) { section.entries.append(ResumeEntry()) }
        } header: {
            if section.entries.isEmpty { heading }
        }
    }

    private var heading: some View {
        HStack {
            Text(section.kind.heading)
            Spacer()
            Menu {
                Button("Remove Section", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("\(section.kind.heading) options")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

private struct EntryCard: View {
    enum Action {
        case moveUp, moveDown, delete
    }

    @Binding var entry: ResumeEntry
    let kind: ResumeSection.Kind
    let perform: (Action) -> Void

    var body: some View {
        HStack {
            Text(entry.title.isBlank ? kind.newEntryTitle : entry.title)
                .font(.headline)
                .foregroundStyle(entry.title.isBlank ? .secondary : .primary)
            Spacer()
            Menu {
                Button("Move Up") { perform(.moveUp) }
                Button("Move Down") { perform(.moveDown) }
                Divider()
                Button("Delete", role: .destructive) { perform(.delete) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Entry options")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }

        TextField(kind.titleLabel, text: $entry.title, prompt: Text(kind.titlePrompt))
        TextField(kind.subtitleLabel, text: $entry.subtitle, prompt: Text(kind.subtitlePrompt))
        if kind != .skills {
            TextField("Dates", text: $entry.dates, prompt: Text("Mar 2024 – Present"))
            StringListEditor(
                items: $entry.bullets,
                prompt: String(localized: "What you did and the result"),
                addTitle: String(localized: "Add Bullet Point")
            )
        }
    }
}

/// Field labels and button titles that say what each section actually holds.
private extension ResumeSection.Kind {
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
        case .experience, .organizational: String(localized: "Organization")
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
    @Previewable @State var document = ResumeDocument.blank
    Form {
        ResumeSectionsForm(document: $document)
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 700)
}
