//
//  ResumeSectionsForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Edits a resume's sections and entries (FR-034). Entries here are the resume's own copies;
/// changing them never touches the Career Profile.
struct ResumeSectionsForm: View {
    @Binding var document: ResumeDocument

    var body: some View {
        ForEach($document.sections) { $section in
            Section {
                ForEach($section.entries) { $entry in
                    EntryEditor(entry: $entry, kind: section.kind) { action in
                        switch action {
                        case .moveUp: section.entries.move(id: entry.id, by: -1)
                        case .moveDown: section.entries.move(id: entry.id, by: 1)
                        case .remove: section.entries.removeAll { $0.id == entry.id }
                        }
                    }
                }
                AddButton(title: String(localized: "Add Entry")) {
                    section.entries.append(ResumeEntry())
                }
            } header: {
                HStack {
                    Text(section.kind.heading)
                    Spacer()
                    Group {
                        Button("Move Section Up", systemImage: "arrow.up") {
                            document.sections.move(id: section.id, by: -1)
                        }
                        .disabled(document.sections.first?.id == section.id)
                        Button("Move Section Down", systemImage: "arrow.down") {
                            document.sections.move(id: section.id, by: 1)
                        }
                        .disabled(document.sections.last?.id == section.id)
                        Button("Remove Section", systemImage: "trash", role: .destructive) {
                            document.sections.removeAll { $0.id == section.id }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
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

private struct EntryEditor: View {
    enum Action {
        case moveUp, moveDown, remove
    }

    @Binding var entry: ResumeEntry
    let kind: ResumeSection.Kind
    let perform: (Action) -> Void

    var body: some View {
        DisclosureGroup {
            if kind == .skills {
                TextField("Category", text: $entry.title, prompt: Text("Languages"))
                TextField("Skills", text: $entry.subtitle, prompt: Text("Swift, Kotlin, Python"))
            } else {
                TextField("Title", text: $entry.title, prompt: Text("Role, degree, or name"))
                TextField("Subtitle", text: $entry.subtitle, prompt: Text("Organization · Location"))
                TextField("Dates", text: $entry.dates, prompt: Text("Mar 2024 – Present"))
                StringListEditor(
                    items: $entry.bullets,
                    prompt: String(localized: "What you did and the result"),
                    addTitle: String(localized: "Add Bullet")
                )
            }
            HStack {
                Button("Move Up") { perform(.moveUp) }
                Button("Move Down") { perform(.moveDown) }
                Spacer()
                Button("Remove Entry", role: .destructive) { perform(.remove) }
            }
            .buttonStyle(.borderless)
        } label: {
            Text(label)
                .foregroundStyle(entry.title.isBlank && entry.subtitle.isBlank ? .secondary : .primary)
        }
    }

    private var label: String {
        [entry.title, entry.subtitle].first { !$0.isBlank } ?? String(localized: "New Entry")
    }
}

#Preview {
    @Previewable @State var document = ResumeDocument.blank
    Form {
        ResumeSectionsForm(document: $document)
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 600)
}
