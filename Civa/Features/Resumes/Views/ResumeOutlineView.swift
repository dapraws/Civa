//
//  ResumeOutlineView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// The resume's structure in page order. Drag sections and entries to reorder them (FR-036).
struct ResumeOutlineView: View {
    @Binding var document: ResumeDocument
    @Binding var selection: ResumeOutlineItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Resume Info", systemImage: "info.circle")
                    .tag(ResumeOutlineItem.info)
                HStack(spacing: 4) {
                    Label("Header and Summary", systemImage: "person.crop.rectangle")
                    if document.claudeTouchedSummary == true {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.claude)
                            .help("Claude wrote the summary")
                    }
                }
                    .tag(ResumeOutlineItem.header)
            }
            Section("Sections") {
                ForEach(document.outlineRows) { row in
                    let section = document.sections[row.section]
                    if let entry = row.entry {
                        entryRow(section.entries[entry], kind: section.kind)
                    } else {
                        sectionRow(section)
                    }
                }
                .onMove { document.moveOutlineRow(from: $0, to: $1) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addSectionBar
        }
    }

    private func sectionRow(_ section: ResumeSection) -> some View {
        Label(section.title, systemImage: section.kind.systemImage)
            .fontWeight(.medium)
            .tag(ResumeOutlineItem.section(section.id))
            .contextMenu {
                Button(section.kind.addTitle) { addEntry(to: section.id) }
                Divider()
                Button("Remove Section", role: .destructive) { removeSection(section.id) }
            }
    }

    private func entryRow(_ entry: ResumeEntry, kind: ResumeSection.Kind) -> some View {
        HStack(spacing: 4) {
            Text(entry.title.isBlank ? kind.newEntryTitle : entry.title)
                .foregroundStyle(entry.title.isBlank ? .secondary : .primary)
                .lineLimit(1)
            if entry.claudeTouched == true {
                Image(systemName: "sparkles")
                    .foregroundStyle(.claude)
                    .help("Claude wrote part of this")
            }
        }
        .padding(.leading, 26)
            .tag(ResumeOutlineItem.entry(entry.id))
            .contextMenu {
                Button("Delete", role: .destructive) { deleteEntry(entry.id) }
            }
    }

    @ViewBuilder
    private var addSectionBar: some View {
        let missing = ResumeSection.Kind.allCases.filter { kind in !document.sections.contains { $0.kind == kind } }
        if !missing.isEmpty {
            HStack {
                Menu {
                    ForEach(missing, id: \.self) { kind in
                        Button(kind.heading) {
                            let section = ResumeSection(kind: kind)
                            document.sections.append(section)
                            selection = .section(section.id)
                        }
                    }
                } label: {
                    Label("Add Section", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
            }
            .padding(10)
            .background(.bar)
        }
    }

    private func addEntry(to id: UUID) {
        guard let index = document.sections.firstIndex(where: { $0.id == id }) else { return }
        let entry = ResumeEntry()
        document.sections[index].entries.append(entry)
        selection = .entry(entry.id)
    }

    private func removeSection(_ id: UUID) {
        if selection == .section(id) || document.sections.first(where: { $0.id == id })?.entries
            .contains(where: { selection == .entry($0.id) }) == true {
            selection = .header
        }
        document.sections.removeAll { $0.id == id }
    }

    private func deleteEntry(_ id: UUID) {
        guard let position = document.entryPosition(id) else { return }
        if selection == .entry(id) { selection = .section(document.sections[position.section].id) }
        document.sections[position.section].entries.remove(at: position.entry)
    }
}

#Preview {
    @Previewable @State var document = ResumeDocument.blank
    @Previewable @State var selection: ResumeOutlineItem? = .header
    ResumeOutlineView(document: $document, selection: $selection)
        .frame(width: 240, height: 500)
}
