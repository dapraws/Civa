//
//  ResumeOutline.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftUI  // move(fromOffsets:toOffset:)

/// What the editor's outline can select.
nonisolated enum ResumeOutlineItem: Hashable {
    case info, header, summary
    case section(UUID)
    case entry(UUID)
}

/// One outline row: a section, or one of its entries.
nonisolated struct ResumeOutlineRow: Identifiable, Hashable {
    let id: UUID
    let section: Int
    /// nil for the section's own row.
    let entry: Int?
}

nonisolated extension ResumeDocument {
    /// Sections with their entries under them, flattened so one list and one drag handler cover both.
    var outlineRows: [ResumeOutlineRow] {
        sections.indices.flatMap { s in
            [ResumeOutlineRow(id: sections[s].id, section: s, entry: nil)]
                + sections[s].entries.indices.map { ResumeOutlineRow(id: sections[s].entries[$0].id, section: s, entry: $0) }
        }
    }

    /// Applies a drag in the outline (FR-036). A section moves with its entries; an entry moves only
    /// within its own section, since a degree doesn't belong under Experience.
    mutating func moveOutlineRow(from source: IndexSet, to destination: Int) {
        let rows = outlineRows
        guard source.count == 1, let from = source.first, rows.indices.contains(from) else { return }
        let headers = rows.indices.filter { rows[$0].entry == nil }
        let row = rows[from]
        if let entry = row.entry {
            let offset = destination - (headers[row.section] + 1)
            guard (0...sections[row.section].entries.count).contains(offset) else { return }
            sections[row.section].entries.move(fromOffsets: [entry], toOffset: offset)
        } else {
            sections.move(fromOffsets: [row.section], toOffset: headers.filter { $0 < destination }.count)
        }
    }

    /// Where an entry is, by id.
    func entryPosition(_ id: UUID) -> (section: Int, entry: Int)? {
        for s in sections.indices {
            if let e = sections[s].entries.firstIndex(where: { $0.id == id }) { return (s, e) }
        }
        return nil
    }
}
