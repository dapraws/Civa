//
//  SuggestedChanges.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// The Career Profile as resumes see it. Only confirmed records count; unconfirmed data never
/// flows into a resume (FR-015).
struct ProfileSource {
    /// Confirmed records in resume form, by record id.
    var entries: [UUID: ResumeEntry] = [:]
    /// Every record id, confirmed or not, to tell a deleted record from one awaiting review.
    var knownIDs: Set<UUID> = []
    /// Personal Information in resume form, when confirmed.
    var header: ResumeHeader?

    init(person: PersonalInfo?, records: [any ImportableRecord]) {
        if let person, !person.needsReview { header = ResumeBuilder.header(from: person) }
        for record in records {
            knownIDs.insert(record.id)
            if !record.needsReview, let entry = ResumeBuilder.entry(for: record) { entries[record.id] = entry }
        }
    }

    // ponytail: fetches the whole profile on each call; fine at profile sizes, cache if it shows up in profiles.
    static func current(in context: ModelContext) -> ProfileSource {
        func all<M: ImportableRecord>(_ type: M.Type) -> [any ImportableRecord] {
            (try? context.fetch(FetchDescriptor<M>())) ?? []
        }
        let records = all(Experience.self) + all(Education.self) + all(Project.self)
            + all(Achievement.self) + all(Certification.self) + all(Skill.self)
        return ProfileSource(person: (try? context.fetch(FetchDescriptor<PersonalInfo>()))?.first, records: records)
    }
}

/// One suggestion: a profile change that this resume doesn't have yet (FR-042).
struct ResumeSuggestion: Identifiable, Hashable {
    enum Target: Hashable {
        case header
        case entry(UUID)
        /// The profile record this entry came from was deleted.
        case removedEntry(UUID)
    }

    struct Change: Hashable {
        let label: String
        let old: String
        let new: String
        /// The resume had its own wording here, which applying replaces.
        let replacesEdit: Bool
    }

    let target: Target
    let title: String
    let changes: [Change]
    var id: Target { target }
}

/// Finds Career Profile changes a resume hasn't taken yet, and applies or dismisses them (FR-042).
/// Each entry remembers the profile version it was copied from, so only the profile's own changes
/// are suggested, never the user's edits in the resume. Nothing changes until the user chooses.
enum SuggestedChanges {
    static func suggestions(for document: ResumeDocument, from profile: ProfileSource) -> [ResumeSuggestion] {
        var suggestions: [ResumeSuggestion] = []
        if let old = document.headerSource, let new = profile.header, old != new {
            func links(_ header: ResumeHeader) -> String { header.links.map(\.url).joined(separator: ", ") }
            let changes = headerFields.compactMap { label, field in
                change(label, old: old[keyPath: field], new: new[keyPath: field], current: document.header[keyPath: field])
            } + [change(String(localized: "Links"), old: links(old), new: links(new), current: links(document.header))].compactMap { $0 }
            if !changes.isEmpty {
                suggestions.append(ResumeSuggestion(target: .header, title: String(localized: "Header"), changes: changes))
            }
        }
        for section in document.sections {
            for entry in section.entries {
                guard let id = entry.sourceID, let old = entry.sourceCopy else { continue }
                let name = "\(section.kind.heading): \(entry.title.isBlank ? section.kind.newEntryTitle : entry.title)"
                if !profile.knownIDs.contains(id) {
                    suggestions.append(ResumeSuggestion(
                        target: .removedEntry(entry.id),
                        title: name,
                        changes: [.init(label: String(localized: "Removed from your profile"), old: entry.title, new: "", replacesEdit: false)]
                    ))
                } else if let new = profile.entries[id]?.asSourceCopy, new != old {
                    let changes = entryChanges(old: old, new: new, current: entry, kind: section.kind)
                    if !changes.isEmpty {
                        suggestions.append(ResumeSuggestion(target: .entry(entry.id), title: name, changes: changes))
                    }
                }
            }
        }
        return suggestions
    }

    /// Takes the profile's changes into the resume. Wording the profile didn't change stays.
    static func apply(_ suggestion: ResumeSuggestion, to document: inout ResumeDocument, from profile: ProfileSource) {
        switch suggestion.target {
        case .header:
            guard let old = document.headerSource, let new = profile.header else { return }
            for (_, field) in headerFields where old[keyPath: field] != new[keyPath: field] {
                document.header[keyPath: field] = new[keyPath: field]
            }
            if old.links != new.links { document.header.links = new.links }
            document.headerSource = new
        case .entry(let id):
            guard let position = document.entryPosition(id) else { return }
            var entry = document.sections[position.section].entries[position.entry]
            guard let old = entry.sourceCopy, let sourceID = entry.sourceID, let new = profile.entries[sourceID]?.asSourceCopy else { return }
            if old.title != new.title { entry.title = new.title }
            if old.subtitle != new.subtitle { entry.subtitle = new.subtitle }
            if old.dates != new.dates { entry.dates = new.dates }
            if old.employmentType != new.employmentType { entry.employmentType = new.employmentType }
            let removed = Set(old.bullets).subtracting(new.bullets)
            entry.bullets.removeAll { removed.contains($0) }
            entry.bullets += new.bullets.filter { !old.bullets.contains($0) && !entry.bullets.contains($0) }
            entry.sourceCopy = new
            document.sections[position.section].entries[position.entry] = entry
        case .removedEntry(let id):
            guard let position = document.entryPosition(id) else { return }
            document.sections[position.section].entries.remove(at: position.entry)
        }
    }

    /// Keeps the resume as it is. Only later profile changes will be suggested.
    static func dismiss(_ suggestion: ResumeSuggestion, in document: inout ResumeDocument, from profile: ProfileSource) {
        switch suggestion.target {
        case .header:
            document.headerSource = profile.header
        case .entry(let id):
            guard let position = document.entryPosition(id),
                  let sourceID = document.sections[position.section].entries[position.entry].sourceID
            else { return }
            document.sections[position.section].entries[position.entry].sourceCopy = profile.entries[sourceID]?.asSourceCopy
        case .removedEntry(let id):
            // Keeps the entry as resume-only text.
            guard let position = document.entryPosition(id) else { return }
            document.sections[position.section].entries[position.entry].sourceID = nil
            document.sections[position.section].entries[position.entry].sourceCopy = nil
        }
    }

    /// Resumes made before suggestions existed start tracking from the profile as it is now, so
    /// earlier differences (often the user's own edits) aren't suggested. Returns whether it changed anything.
    @discardableResult
    static func startTracking(_ document: inout ResumeDocument, from profile: ProfileSource) -> Bool {
        var changed = false
        if document.headerSource == nil, let header = profile.header, !header.fullName.isBlank,
           header.fullName.lowercased() == document.header.fullName.lowercased() {
            document.headerSource = header
            changed = true
        }
        for s in document.sections.indices {
            for e in document.sections[s].entries.indices {
                let entry = document.sections[s].entries[e]
                guard entry.sourceCopy == nil, let id = entry.sourceID, let current = profile.entries[id] else { continue }
                document.sections[s].entries[e].sourceCopy = current.asSourceCopy
                changed = true
            }
        }
        return changed
    }

    // MARK: - Fields

    private static var headerFields: [(String, WritableKeyPath<ResumeHeader, String>)] {
        [
            (String(localized: "Full Name"), \.fullName),
            (String(localized: "Headline"), \.headline),
            (String(localized: "Email"), \.email),
            (String(localized: "Phone"), \.phone),
            (String(localized: "Location"), \.location),
        ]
    }

    /// A change worth suggesting: the profile moved, and the resume doesn't already say the new thing.
    private static func change(_ label: String, old: String, new: String, current: String) -> ResumeSuggestion.Change? {
        guard old != new, current != new else { return nil }
        return .init(label: label, old: current, new: new, replacesEdit: current != old)
    }

    private static func entryChanges(
        old: ResumeEntry.SourceCopy, new: ResumeEntry.SourceCopy, current: ResumeEntry, kind: ResumeSection.Kind
    ) -> [ResumeSuggestion.Change] {
        var changes = [
            change(kind.titleLabel, old: old.title, new: new.title, current: current.title),
            change(kind.subtitleLabel, old: old.subtitle, new: new.subtitle, current: current.subtitle),
            change(String(localized: "Dates"), old: old.dates, new: new.dates, current: current.dates),
            change(
                String(localized: "Employment Type"),
                old: old.employmentType ?? "", new: new.employmentType ?? "", current: current.employmentType ?? ""
            ),
        ]
        .compactMap { $0 }
        for line in new.bullets where !old.bullets.contains(line) && !current.bullets.contains(line) {
            changes.append(.init(label: String(localized: "Line added"), old: "", new: line, replacesEdit: false))
        }
        for line in old.bullets where !new.bullets.contains(line) && current.bullets.contains(line) {
            changes.append(.init(label: String(localized: "Line removed"), old: line, new: "", replacesEdit: false))
        }
        return changes
    }
}
