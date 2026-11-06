//
//  ResumeDiff.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// One plain-language difference between two versions of a resume.
struct ResumeChange: Hashable {
    let systemImage: String
    let text: String
}

/// What changed from an older version to a newer one, for comparing versions (FR-043).
/// Sections are matched by kind and entries by id, which copies and snapshots keep.
enum ResumeDiff {
    static func changes(from old: ResumeDocument, to new: ResumeDocument) -> [ResumeChange] {
        var changes: [ResumeChange] = []
        if old.header != new.header {
            changes.append(.init(systemImage: "person.crop.rectangle", text: String(localized: "Header edited")))
        }
        if old.summary != new.summary {
            changes.append(.init(systemImage: "text.alignleft", text: String(localized: "Summary edited")))
        }

        let oldKinds = old.sections.map(\.kind)
        let newKinds = new.sections.map(\.kind)
        for kind in newKinds where !oldKinds.contains(kind) {
            changes.append(.init(systemImage: "plus", text: String(localized: "\(kind.heading) section added")))
        }
        for kind in oldKinds where !newKinds.contains(kind) {
            changes.append(.init(systemImage: "minus", text: String(localized: "\(kind.heading) section removed")))
        }
        if oldKinds.filter(newKinds.contains) != newKinds.filter(oldKinds.contains) {
            changes.append(.init(systemImage: "arrow.up.arrow.down", text: String(localized: "Sections reordered")))
        }

        for section in new.sections {
            guard let oldSection = old.sections.first(where: { $0.kind == section.kind }) else { continue }
            changes += entryChanges(from: oldSection, to: section)
        }

        changes += formatChanges(from: old.format, to: new.format)
        return changes
    }

    private static func entryChanges(from old: ResumeSection, to new: ResumeSection) -> [ResumeChange] {
        let heading = new.kind.heading
        let oldIDs = old.entries.map(\.id)
        let newIDs = new.entries.map(\.id)
        func name(_ entry: ResumeEntry) -> String { entry.title.isBlank ? new.kind.newEntryTitle : entry.title }

        var changes: [ResumeChange] = []
        for entry in new.entries where !oldIDs.contains(entry.id) {
            changes.append(.init(systemImage: "plus", text: String(localized: "\(heading): added “\(name(entry))”")))
        }
        for entry in old.entries where !newIDs.contains(entry.id) {
            changes.append(.init(systemImage: "minus", text: String(localized: "\(heading): removed “\(name(entry))”")))
        }
        for entry in new.entries {
            if let before = old.entries.first(where: { $0.id == entry.id }), before != entry {
                changes.append(.init(systemImage: "pencil", text: String(localized: "\(heading): edited “\(name(entry))”")))
            }
        }
        if oldIDs.filter(newIDs.contains) != newIDs.filter(oldIDs.contains) {
            changes.append(.init(systemImage: "arrow.up.arrow.down", text: String(localized: "\(heading): entries reordered")))
        }
        return changes
    }

    private static func formatChanges(from old: ResumeFormat, to new: ResumeFormat) -> [ResumeChange] {
        func change(_ label: String, _ before: String, _ after: String) -> ResumeChange? {
            before == after ? nil : .init(systemImage: "textformat", text: "\(label): \(before) → \(after)")
        }
        return [
            change(String(localized: "Font"), old.font.rawValue, new.font.rawValue),
            change(String(localized: "Font size"), "\(old.fontSize.formatted()) pt", "\(new.fontSize.formatted()) pt"),
            change(String(localized: "Line spacing"), old.lineSpacing.formatted(), new.lineSpacing.formatted()),
            change(String(localized: "Space between sections"), "\(old.sectionSpacing.formatted()) pt", "\(new.sectionSpacing.formatted()) pt"),
            change(String(localized: "Margins"), old.margins.title, new.margins.title),
            change(String(localized: "Accent color"), old.accent.title, new.accent.title),
            change(String(localized: "Paper"), old.paper.title, new.paper.title),
            change(
                String(localized: "Employment types"),
                old.showsEmploymentType == true ? String(localized: "Shown") : String(localized: "Hidden"),
                new.showsEmploymentType == true ? String(localized: "Shown") : String(localized: "Hidden")
            ),
        ]
        .compactMap { $0 }
    }
}
