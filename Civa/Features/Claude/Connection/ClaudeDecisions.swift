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
    /// `choice` names the picked versions when Claude offered options.
    static func record(_ proposalID: UUID, _ status: ClaudeProposal.Status, container: ModelContainer, choice: String? = nil) {
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
            detail: choice.map { String(localized: "Chose \($0)") } ?? proposal.note
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
        if let removals = edit.removals {
            for s in document.sections.indices { document.sections[s].entries.removeAll { removals.contains($0.id) } }
        }
        for addition in edit.additions ?? [] {
            add(addition.entry, kind: addition.kind, to: &document)
        }
        reorder(&document, sections: edit.sectionOrder, entries: edit.entryOrder)
    }

    /// Takes a resume edit into the resume, including making it the Master Resume.
    static func apply(_ edit: ClaudeProposal.ResumeEdit, to resume: Resume, in context: ModelContext) throws {
        var document = resume.document
        apply(edit, to: &document)
        resume.document = document
        if edit.makeMaster == true { try Resume.makeMaster(resume, in: context) }
    }

    /// Adds an entry to the first section of `kind`, making the section when there's none. A
    /// skill line joins the line of the same category; a record already in the resume is skipped.
    static func add(_ entry: ResumeEntry, kind: ResumeSection.Kind, to document: inout ResumeDocument) {
        let index = document.sections.firstIndex { $0.kind == kind } ?? {
            document.sections.append(ResumeSection(kind: kind))
            return document.sections.count - 1
        }()
        var entries = document.sections[index].entries
        if kind == .skills, let line = entries.firstIndex(where: { $0.title.lowercased() == entry.title.lowercased() }) {
            let names = (entries[line].subtitle.components(separatedBy: ", ") + entry.subtitle.components(separatedBy: ", ")).filter { !$0.isBlank }
            var seen = Set<String>()
            entries[line].subtitle = ResumeBuilder.skillList(names.filter { seen.insert($0.lowercased()).inserted })
            if var copy = entries[line].sourceCopy, let added = entry.sourceCopy?.skills {
                copy.skills = (copy.skills ?? [:]).merging(added) { old, _ in old }
                entries[line].sourceCopy = copy
            }
        } else if entry.sourceID == nil || !entries.contains(where: { $0.sourceID == entry.sourceID }) {
            entries.append(entry)
        }
        document.sections[index].entries = entries
    }

    /// Puts sections (by id or kind) and entries (by id) in the given order; the rest follow in theirs.
    static func reorder(_ document: inout ResumeDocument, sections: [String]?, entries: [UUID]?) {
        if let entries, !entries.isEmpty {
            let rank = Dictionary(entries.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            for s in document.sections.indices {
                document.sections[s].entries = document.sections[s].entries.enumerated()
                    .sorted { (rank[$0.element.id] ?? Int.max, $0.offset) < (rank[$1.element.id] ?? Int.max, $1.offset) }
                    .map(\.element)
            }
        }
        if let sections, !sections.isEmpty {
            let keys = sections.map { $0.lowercased() }
            func rank(_ section: ResumeSection) -> Int {
                keys.firstIndex(of: section.id.uuidString.lowercased()) ?? keys.firstIndex(of: section.kind.rawValue) ?? Int.max
            }
            document.sections = document.sections.enumerated()
                .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
                .map(\.element)
        }
    }

    /// Records from Claude in the import review's form.
    static func draft(from payload: ClaudeProposal.ProfileImport) -> ImportDraft {
        var draft = ImportDraft()
        draft.items = payload.records.compactMap { record in
            guard let (category, _) = ClaudeWriteTools.importCategory(record.category) else { return nil }
            // The import review's subtitle is the issuer for recognition and the role for projects.
            let subtitle = [record.subtitle, record.issuer, record.role].compactMap(\.self).first { !$0.isBlank } ?? ""
            var item = ImportItem(
                category: category, title: record.title, subtitle: subtitle, location: record.location ?? "",
                start: yearMonth(record.start ?? record.issued), end: yearMonth(record.end), isCurrent: record.current ?? false,
                bullets: record.bullets ?? []
            )
            item.url = record.url ?? ""
            item.credentialURL = record.credentialURL ?? ""
            item.credentialID = record.credentialID ?? ""
            item.expires = yearMonth(record.expires)
            item.fieldOfStudy = record.fieldOfStudy ?? ""
            item.grade = record.grade ?? ""
            item.placement = record.placement ?? ""
            item.score = record.score ?? ""
            return item
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

/// A profile record whose fields Claude can suggest: every text it has, and its lists of lines.
protocol ClaudeEditable: ProfileRecord {
    var id: UUID { get }
    static var claudeCategory: ClaudeCategory { get }
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Self, String>] { get }
    static var lineFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Self, [String]>] { get }
}

extension ClaudeEditable {
    static var lineFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Self, [String]>] { [:] }

    static var editableFields: Set<ClaudeProposal.RecordEdit.Field> { Set(textFields.keys).union(lineFields.keys) }

    func current(_ field: ClaudeProposal.RecordEdit.Field) -> [String] {
        if let path = Self.lineFields[field] { return self[keyPath: path] }
        return Self.textFields[field].map { [self[keyPath: $0]] } ?? []
    }

    func apply(_ edit: ClaudeProposal.RecordEdit) {
        if let path = Self.lineFields[edit.field], let lines = edit.lines { self[keyPath: path] = lines }
        if let path = Self.textFields[edit.field], let text = edit.text { self[keyPath: path] = text }
    }
}

extension Experience: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.experience
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Experience, String>] {
        [.role: \.role, .organization: \.organization, .location: \.location, .details: \.details, .recognition: \.recognition]
    }
    static var lineFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Experience, [String]>] { [.impacts: \.impacts] }
}

extension Project: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.projects
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Project, String>] {
        [.name: \.name, .role: \.role, .details: \.details]
    }
    static var lineFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Project, [String]>] { [.impacts: \.impacts] }
}

extension PersonalInfo: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.personal
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<PersonalInfo, String>] {
        [.headline: \.headline, .summary: \.summary, .location: \.location]
    }
}

extension Education: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.education
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Education, String>] {
        [.institution: \.institution, .degree: \.degree, .fieldOfStudy: \.fieldOfStudy, .location: \.location,
         .thesis: \.thesis, .honors: \.honors, .details: \.details]
    }
    static var lineFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Education, [String]>] { [.coursework: \.coursework] }
}

extension Achievement: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.recognition
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Achievement, String>] {
        [.title: \.title, .issuer: \.issuer, .placement: \.placement, .details: \.details]
    }
}

extension Certification: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.recognition
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Certification, String>] {
        [.name: \.name, .issuer: \.issuer]
    }
}

extension Skill: ClaudeEditable {
    static let claudeCategory = ClaudeCategory.skills
    static var textFields: [ClaudeProposal.RecordEdit.Field: ReferenceWritableKeyPath<Skill, String>] {
        [.name: \.name, .category: \.category]
    }
}
