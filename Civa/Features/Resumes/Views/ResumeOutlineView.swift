//
//  ResumeOutlineView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// The resume's structure in page order. Drag sections and entries to reorder them (FR-036).
/// Rows look like the app sidebar and record lists (DESIGN.md §7.7): soft fill and a cobalt bar
/// when selected, no separators. The List stays for its drag-to-reorder.
struct ResumeOutlineView: View {
    @Binding var document: ResumeDocument
    @Binding var selection: ResumeOutlineItem?

    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    row(.info) { OutlineLabel(title: "Resume Info", systemImage: "info.circle", isSelected: selection == .info) }
                    row(.header) {
                        OutlineLabel(
                            title: "Header and Summary",
                            systemImage: "person.crop.rectangle",
                            isSelected: selection == .header,
                            claudeHelp: document.claudeTouchedSummary == true ? "Claude wrote the summary" : nil
                        )
                    }
                }
                Section(caption: "Sections") {
                    ForEach(document.outlineRows) { outlineRow in
                        let section = document.sections[outlineRow.section]
                        if let entry = outlineRow.entry {
                            entryRow(section.entries[entry], kind: section.kind)
                        } else {
                            sectionRow(section)
                        }
                    }
                    .onMove { document.moveOutlineRow(from: $0, to: $1) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.sidebar)
            .environment(\.defaultMinListRowHeight, Size.sidebarItem)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { step(-1, proxy: proxy) }
            .onKeyPress(.downArrow) { step(1, proxy: proxy) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addSectionBar
        }
    }

    /// Every row in order, for the arrow keys.
    private var items: [ResumeOutlineItem] {
        [.info, .header] + document.outlineRows.map { outlineRow in
            let section = document.sections[outlineRow.section]
            return outlineRow.entry.map { .entry(section.entries[$0].id) } ?? .section(section.id)
        }
    }

    private func step(_ offset: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        let all = items
        let next: ResumeOutlineItem?
        if let index = all.firstIndex(where: { $0 == selection }) {
            guard all.indices.contains(index + offset) else { return .handled }
            next = all[index + offset]
        } else {
            next = offset > 0 ? all.first : all.last
        }
        guard let next else { return .ignored }
        selection = next
        proxy.scrollTo(next)
        return .handled
    }

    /// One row: Civa's look, a click selects, and keyboard focus shows the ring on the selected row.
    private func row<Content: View>(_ item: ResumeOutlineItem, @ViewBuilder content: () -> Content) -> some View {
        content()
            .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isFocused && selection == item)
            .contentShape(.rect)
            .onTapGesture {
                isFocused = true
                selection = item
            }
            .accessibilityAddTraits(selection == item ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = item }
            .id(item)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Space.s, bottom: 1, trailing: Space.s))
    }

    private func sectionRow(_ section: ResumeSection) -> some View {
        row(.section(section.id)) {
            OutlineLabel(title: section.title, systemImage: section.kind.systemImage, isSelected: selection == .section(section.id), isHeading: true)
                .help(section.title)
        }
        .contextMenu {
            Button(section.kind.addTitle) { addEntry(to: section.id) }
            Divider()
            Button("Remove Section", role: .destructive) { removeSection(section.id) }
        }
    }

    private func entryRow(_ entry: ResumeEntry, kind: ResumeSection.Kind) -> some View {
        row(.entry(entry.id)) {
            OutlineLabel(
                title: entry.title.isBlank ? kind.newEntryTitle : entry.title,
                systemImage: nil,
                isSelected: selection == .entry(entry.id),
                isPlaceholder: entry.title.isBlank,
                claudeHelp: entry.claudeTouched == true ? "Claude wrote part of this" : nil
            )
        }
        .contextMenu {
            Button("Delete", role: .destructive) { deleteEntry(entry.id) }
        }
    }

    private func add(_ section: ResumeSection) {
        document.sections.append(section)
        selection = .section(section.id)
    }

    @ViewBuilder
    private var addSectionBar: some View {
        let missing = ResumeSection.Kind.allCases.filter { kind in !document.sections.contains { $0.kind == kind } }
        // Organizational experience can be split: Leadership, Volunteer, and so on, each its own section.
        let usedHeadings = Set(document.sections.filter { $0.kind == .organizational }.map(\.title))
        let organizationalHeadings = missing.contains(.organizational)
            ? []
            : ResumeSection.Kind.organizational.headingOptions.filter { !usedHeadings.contains($0) }
        if !missing.isEmpty || !organizationalHeadings.isEmpty {
            HStack {
                Menu {
                    ForEach(missing, id: \.self) { kind in
                        Button(kind.heading) { add(ResumeSection(kind: kind)) }
                    }
                    if !organizationalHeadings.isEmpty {
                        Divider()
                        ForEach(organizationalHeadings, id: \.self) { heading in
                            Button(heading) { add(ResumeSection(kind: .organizational, heading: heading)) }
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

/// An outline row's label, styled like `SidebarItem`. Entries (no symbol) sit indented under
/// their section.
private struct OutlineLabel: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    var isHeading = false
    var isPlaceholder = false
    /// Shown as a Claude sparkle with this help text.
    var claudeHelp: String?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Space.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: 18, height: 1)
            }
            Text(title)
                .font(isSelected || isHeading ? .bodyEmphasis : .body)
                .foregroundStyle(isPlaceholder ? Color.textSecondary : isSelected || isHovered || isHeading ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
            if let claudeHelp {
                Image(systemName: "sparkles")
                    .foregroundStyle(.claude)
                    .help(claudeHelp)
                    .accessibilityLabel(Text(claudeHelp))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s)
        .frame(height: Size.sidebarItem)
        .background(isSelected ? Color.selectionFill : isHovered ? Color.hover : .clear, in: .rect(cornerRadius: Radius.control))
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accent)
                    .frame(width: 3, height: 14)
                    .padding(.leading, 2)
            }
        }
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
    }
}

private struct OutlinePreview: View {
    @State private var document: ResumeDocument = {
        var document = ResumeDocument.blank
        var experience = ResumeSection(kind: .experience)
        var entry = ResumeEntry()
        entry.title = "iOS Engineer"
        experience.entries = [entry, ResumeEntry()]
        document.sections = [experience, ResumeSection(kind: .education)]
        return document
    }()
    @State private var selection: ResumeOutlineItem? = .header

    var body: some View {
        ResumeOutlineView(document: $document, selection: $selection)
            .frame(width: 240, height: 500)
    }
}

#Preview("Light") {
    OutlinePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    OutlinePreview().preferredColorScheme(.dark)
}
