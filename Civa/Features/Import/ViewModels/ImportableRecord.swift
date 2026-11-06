//
//  ImportableRecord.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// A profile record an import can match, compare, and merge into (FR-024).
nonisolated protocol ImportableRecord: ProfileRecord {
    var id: UUID { get }
    var possibleDuplicateOf: UUID? { get set }
    /// The record's values in import form, for matching and comparing.
    var importItem: ImportItem { get }
    /// Takes `fields` from `item`; everything else stays.
    func apply(_ item: ImportItem, fields: Set<ImportField>)
}

nonisolated extension ImportableRecord {
    /// Merges chosen fields and any new lines, records the source, and asks for review again.
    func merge(_ item: ImportItem, fields: Set<ImportField>, source: RecordSource?) {
        apply(item, fields: fields)
        if let source { addSource(source) }
        status = .needsReview
        updatedAt = .now
    }
}

private nonisolated func lines(_ text: String) -> [String] {
    text.components(separatedBy: .newlines).filter { !$0.isBlank }
}

nonisolated extension Experience: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(
            id: id, category: kind == .professional ? .experience : .organizational, title: role, subtitle: organization,
            location: location, start: start, end: end, isCurrent: isCurrent, bullets: impacts
        )
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { role = item.title }
        if fields.contains(.subtitle) { organization = item.subtitle }
        if fields.contains(.location) { location = item.location }
        if fields.contains(.start) { start = item.start }
        if fields.contains(.end) { end = item.end; isCurrent = item.isCurrent }
        impacts = ImportItem.union(impacts, item.bullets)
    }
}

nonisolated extension Education: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(
            id: id, category: .education, title: degree, subtitle: institution,
            location: location, start: start, end: end, bullets: lines(details)
        )
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { degree = item.title }
        if fields.contains(.subtitle) { institution = item.subtitle }
        if fields.contains(.location) { location = item.location }
        if fields.contains(.start) { start = item.start }
        if fields.contains(.end) { end = item.end }
        details = ImportItem.union(lines(details), item.bullets).joined(separator: "\n")
    }
}

nonisolated extension Project: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(id: id, category: .projects, title: name, subtitle: role, start: start, end: end, bullets: impacts)
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { name = item.title }
        if fields.contains(.subtitle) { role = item.subtitle }
        if fields.contains(.start) { start = item.start }
        if fields.contains(.end) { end = item.end }
        impacts = ImportItem.union(impacts, item.bullets)
    }
}

nonisolated extension Achievement: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(id: id, category: .achievements, title: title, subtitle: issuer, start: date, bullets: lines(details))
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { title = item.title }
        if fields.contains(.subtitle) { issuer = item.subtitle }
        if fields.contains(.start) { date = item.start }
        details = ImportItem.union(lines(details), item.bullets).joined(separator: "\n")
    }
}

nonisolated extension Certification: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(id: id, category: .certifications, title: name, subtitle: issuer, start: issued)
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { name = item.title }
        if fields.contains(.subtitle) { issuer = item.subtitle }
        if fields.contains(.start) { issued = item.start }
    }
}

nonisolated extension Skill: ImportableRecord {
    var importItem: ImportItem {
        ImportItem(id: id, category: .skills, title: name, subtitle: category)
    }

    func apply(_ item: ImportItem, fields: Set<ImportField>) {
        if fields.contains(.title) { name = item.title }
        if fields.contains(.subtitle) { category = item.subtitle }
    }
}
