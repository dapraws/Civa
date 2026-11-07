//
//  ClaudeDecisions.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Applying and dismissing Claude's suggestions (FR-073), and logging the decision (FR-074).
enum ClaudeDecisions {
    /// Marks a suggestion applied or dismissed and logs it. Uses its own context, so an open
    /// editor's unsaved changes are never saved along with it.
    static func record(_ proposalID: UUID, _ status: ClaudeProposal.Status, container: ModelContainer) {
        let context = ModelContext(container)
        guard let proposal = try? context.fetch(FetchDescriptor<ClaudeProposal>(predicate: #Predicate { $0.id == proposalID })).first else { return }
        proposal.status = status
        proposal.decidedAt = .now
        context.insert(ClaudeActivity(
            kind: status == .applied ? .approved : .rejected,
            tool: proposal.kindRaw, category: proposal.category,
            summary: status == .applied
                ? String(localized: "Applied Claude's suggestion for “\(proposal.targetTitle)”")
                : String(localized: "Dismissed Claude's suggestion for “\(proposal.targetTitle)”"),
            detail: proposal.note
        ))
        try? context.save()
    }

    /// Takes a resume edit into the document. Entries that no longer exist are skipped.
    static func apply(_ edit: ClaudeProposal.ResumeEdit, to document: inout ResumeDocument) {
        if let summary = edit.summary {
            document.summary = summary
            document.claudeTouchedSummary = true
        }
        for change in edit.entries {
            guard let position = document.entryPosition(change.entryID) else { continue }
            var entry = document.sections[position.section].entries[position.entry]
            let before = entry
            if let title = change.title, !title.isBlank { entry.title = title }
            if let subtitle = change.subtitle, !subtitle.isBlank { entry.subtitle = subtitle }
            if let bullets = change.bullets, !bullets.isEmpty { entry.bullets = bullets }
            if entry != before { entry.claudeTouched = true }
            document.sections[position.section].entries[position.entry] = entry
        }
    }

    /// Records from Claude in the import review's form.
    static func draft(from payload: ClaudeProposal.ProfileImport) -> ImportDraft {
        var draft = ImportDraft()
        draft.items = payload.records.compactMap { record in
            guard let (category, _) = ClaudeWriteTools.importCategory(record.category) else { return nil }
            return ImportItem(
                category: category, title: record.title, subtitle: record.subtitle ?? "", location: record.location ?? "",
                start: yearMonth(record.start), end: yearMonth(record.end), isCurrent: record.current ?? false,
                bullets: record.bullets ?? []
            )
        }
        return draft
    }

    /// "2024-03" or "2024".
    static func yearMonth(_ text: String?) -> YearMonth? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), let year = parts.first, (1900...2200).contains(year) else { return nil }
        return YearMonth(year: year, month: parts.count > 1 && (1...12).contains(parts[1]) ? parts[1] : nil)
    }

    /// How a suggestion reads in a list.
    static func describe(_ proposal: ClaudeProposal) -> String {
        switch proposal.kind {
        case .resumeEdit: String(localized: "New wording for “\(proposal.targetTitle)”")
        case .recordEdit: String(localized: "A change to “\(proposal.targetTitle)”")
        case .resumeDraft: String(localized: "A draft resume: “\(proposal.targetTitle)”")
        case .profileImport: String(localized: "Records from \(proposal.targetTitle)")
        }
    }
}

/// A profile record whose fields Claude can suggest (impacts, details, summary, headline).
protocol ClaudeEditable: ProfileRecord {
    var id: UUID { get }
    func current(_ field: ClaudeProposal.RecordEdit.Field) -> [String]
    func apply(_ edit: ClaudeProposal.RecordEdit)
}

extension Experience: ClaudeEditable {
    func current(_ field: ClaudeProposal.RecordEdit.Field) -> [String] {
        field == .impacts ? impacts : [details]
    }

    func apply(_ edit: ClaudeProposal.RecordEdit) {
        switch edit.field {
        case .impacts: impacts = edit.lines ?? impacts
        case .details: details = edit.text ?? details
        case .summary, .headline: break
        }
    }
}

extension Project: ClaudeEditable {
    func current(_ field: ClaudeProposal.RecordEdit.Field) -> [String] {
        field == .impacts ? impacts : [details]
    }

    func apply(_ edit: ClaudeProposal.RecordEdit) {
        switch edit.field {
        case .impacts: impacts = edit.lines ?? impacts
        case .details: details = edit.text ?? details
        case .summary, .headline: break
        }
    }
}

extension PersonalInfo: ClaudeEditable {
    func current(_ field: ClaudeProposal.RecordEdit.Field) -> [String] {
        field == .headline ? [headline] : [summary]
    }

    func apply(_ edit: ClaudeProposal.RecordEdit) {
        switch edit.field {
        case .summary: summary = edit.text ?? summary
        case .headline: headline = edit.text ?? headline
        case .impacts, .details: break
        }
    }
}
