//
//  ImportDraft.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Where an imported item goes in the Career Profile.
nonisolated enum ImportCategory: String, CaseIterable, Identifiable {
    case experience, organizational, education, projects, achievements, certifications, skills

    var id: Self { self }

    var title: String {
        switch self {
        case .experience: String(localized: "Professional Experience")
        case .organizational: String(localized: "Organizational Experience")
        case .education: String(localized: "Education")
        case .projects: String(localized: "Projects")
        case .achievements: String(localized: "Achievements")
        case .certifications: String(localized: "Certifications")
        case .skills: String(localized: "Skills")
        }
    }

    /// Labels for an item's two text fields.
    var titleLabel: String {
        switch self {
        case .experience, .organizational: String(localized: "Role")
        case .education: String(localized: "Degree")
        case .projects: String(localized: "Project")
        case .achievements: String(localized: "Award")
        case .certifications: String(localized: "Certificate")
        case .skills: String(localized: "Skill")
        }
    }

    var subtitleLabel: String {
        switch self {
        case .experience: String(localized: "Company")
        case .organizational: String(localized: "Organization")
        case .education: String(localized: "Institution")
        case .projects: String(localized: "Your Role")
        case .achievements, .certifications: String(localized: "Issuer")
        case .skills: String(localized: "Category")
        }
    }
}

/// What happens to an imported item.
nonisolated enum ImportAction: Hashable {
    /// A new record. If it matches an existing one, it's flagged as a possible duplicate.
    case add
    /// Chosen fields go into the matching record (FR-024).
    case merge
    case skip
}

/// A field that can differ between an imported item and the record it matches.
nonisolated enum ImportField: CaseIterable, Hashable {
    case title, subtitle, location, start, end

    func label(for category: ImportCategory) -> String {
        switch self {
        case .title: category.titleLabel
        case .subtitle: category.subtitleLabel
        case .location: String(localized: "Location")
        case .start: category.isSingleDate ? String(localized: "Date") : String(localized: "Start")
        case .end: String(localized: "End")
        }
    }
}

nonisolated extension ImportCategory {
    var isSingleDate: Bool { self == .achievements || self == .certifications }

    var fields: [ImportField] {
        switch self {
        case .experience, .organizational, .education: [.title, .subtitle, .location, .start, .end]
        case .projects: [.title, .subtitle, .start, .end]
        case .achievements, .certifications: [.title, .subtitle, .start]
        case .skills: [.title, .subtitle]
        }
    }
}

/// One thing found in a CV, editable before it's added (FR-020).
nonisolated struct ImportItem: Identifiable, Hashable {
    var id = UUID()
    var category: ImportCategory
    var title = ""
    var subtitle = ""
    var location = ""
    var start: YearMonth?
    var end: YearMonth?
    var isCurrent = false
    var bullets: [String] = []
    var action = ImportAction.add
    /// The existing record this matches, if any.
    var matchID: UUID?
    /// Matches with nothing new, so it starts skipped.
    var isIdentical = false
    /// Fields that take the CV's value when merging; the rest keep the profile's.
    var picks: Set<ImportField> = []

    var isIncluded: Bool {
        get { action != .skip }
        set { action = newValue ? (matchID == nil || category == .skills ? .add : .merge) : .skip }
    }

    /// Something the parser couldn't fill and the user should look at.
    var needsCheck: Bool {
        switch category {
        case .skills: title.isBlank
        case .achievements, .certifications: title.isBlank
        case .experience, .organizational, .education, .projects:
            title.isBlank || subtitle.isBlank || (start == nil && !isCurrent)
        }
    }

    /// How a field reads, for comparing. "Present" stands for a current end date.
    func display(_ field: ImportField) -> String {
        switch field {
        case .title: title
        case .subtitle: subtitle
        case .location: location
        case .start: start?.formatted() ?? ""
        case .end: isCurrent ? String(localized: "Present") : (end?.formatted() ?? "")
        }
    }

    /// `existing` plus any lines from `new` it doesn't already have, ignoring case.
    static func union(_ existing: [String], _ new: [String]) -> [String] {
        var seen = Set(existing.map { $0.lowercased() })
        return existing + new.filter { !$0.isBlank && seen.insert($0.lowercased()).inserted }
    }

    /// The record this becomes. Imported data is never confirmed automatically (FR-015, FR-020).
    func record(source: RecordSource) -> any ImportableRecord {
        let details = bullets.joined(separator: "\n")
        let record: any ImportableRecord = switch category {
        case .experience, .organizational:
            Experience(
                kind: category == .experience ? .professional : .organizational,
                organization: subtitle, role: title, location: location,
                start: start, end: end, isCurrent: isCurrent, impacts: bullets, status: .needsReview
            )
        case .education:
            Education(
                institution: subtitle.isBlank ? title : subtitle, degree: subtitle.isBlank ? "" : title,
                location: location, start: start, end: end, details: details, status: .needsReview
            )
        case .projects:
            Project(name: title, role: subtitle, start: start, end: end, impacts: bullets, status: .needsReview)
        case .achievements:
            Achievement(title: title, issuer: subtitle, date: start, details: details, status: .needsReview)
        case .certifications:
            Certification(name: title, issuer: subtitle, issued: start, status: .needsReview)
        case .skills:
            Skill(name: title, category: subtitle, status: .needsReview)
        }
        record.sources = [source]
        record.possibleDuplicateOf = matchID
        return record
    }
}

/// Decides when an imported item and an existing record are the same thing (FR-024).
nonisolated enum ImportMatcher {
    private static let companyWords: Set<String> = [
        "pt", "tbk", "persero", "cv", "inc", "ltd", "llc", "co", "corp", "corporation", "company", "limited", "gmbh",
    ]

    /// Lowercased, without punctuation or company suffixes: "PT Tokopedia Tbk." reads "tokopedia".
    static func normalize(_ text: String) -> String {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .filter { !companyWords.contains(String($0)) }
            .joined(separator: " ")
    }

    static func isMatch(_ item: ImportItem, _ existing: ImportItem) -> Bool {
        guard item.category == existing.category else { return false }
        let sameTitle = !item.title.isBlank && normalize(item.title) == normalize(existing.title)
        switch item.category {
        case .skills, .projects, .achievements, .certifications:
            return sameTitle
        case .experience, .organizational, .education:
            let sameOrganization = !item.subtitle.isBlank && normalize(item.subtitle) == normalize(existing.subtitle)
            return sameOrganization && (sameTitle || overlaps(item, existing))
        }
    }

    static func overlaps(_ a: ImportItem, _ b: ImportItem) -> Bool {
        guard let aStart = a.start, let bStart = b.start else { return false }
        let aEnd = a.isCurrent ? YearMonth.distantFuture : (a.end ?? aStart)
        let bEnd = b.isCurrent ? YearMonth.distantFuture : (b.end ?? bStart)
        return aStart <= bEnd && bStart <= aEnd
    }

    /// Fields where the CV says something the profile doesn't.
    static func differences(_ item: ImportItem, _ existing: ImportItem) -> [ImportField] {
        item.category.fields.filter { field in
            let new = item.display(field)
            return !new.isBlank && normalize(new) != normalize(existing.display(field))
        }
    }
}

nonisolated struct ImportPersonal: Hashable {
    var fullName = ""
    var headline = ""
    var email = ""
    var phone = ""
    var location = ""
    var links: [ProfileLink] = []
    var isIncluded = true

    var isEmpty: Bool {
        [fullName, headline, email, phone, location].allSatisfy(\.isBlank) && links.isEmpty
    }
}

/// Everything found in one CV, before the user adds it.
nonisolated struct ImportDraft {
    var personal = ImportPersonal()
    var items: [ImportItem] = []
    /// Lines that couldn't be placed, kept so nothing is silently dropped.
    var unsorted: [String] = []
    /// Snapshots of the profile records that items matched, by id.
    var existing: [UUID: ImportItem] = [:]

    var includedCount: Int {
        items.count { $0.isIncluded } + (personal.isIncluded && !personal.isEmpty ? 1 : 0)
    }

    /// Links items to the profile records they match. A match with nothing new starts skipped;
    /// one with differences starts as a merge that fills only the profile's empty fields.
    mutating func match(against records: [ImportItem]) {
        for index in items.indices {
            let item = items[index]
            guard let found = records.first(where: { ImportMatcher.isMatch(item, $0) }) else { continue }
            existing[found.id] = found
            items[index].matchID = found.id
            let differences = ImportMatcher.differences(item, found)
            let hasNewLines = ImportItem.union(found.bullets, item.bullets).count > found.bullets.count
            if differences.isEmpty, !hasNewLines {
                items[index].isIdentical = true
                items[index].action = .skip
            } else {
                items[index].action = item.category == .skills ? .skip : .merge
                items[index].picks = Set(differences.filter { found.display($0).isBlank })
            }
        }
    }

    /// Adds, merges, and fills in what the user chose; the caller saves. Everything touched becomes
    /// Needs Review and records `source`. An existing Personal Information record only gets its
    /// empty fields filled, so no value is overwritten. Returns how many records were added or changed.
    @discardableResult
    func add(
        to context: ModelContext,
        existing person: PersonalInfo?,
        records: [UUID: any ImportableRecord],
        source: RecordSource
    ) -> Int {
        var count = 0
        if personal.isIncluded, !personal.isEmpty {
            if let person {
                var filled = false
                func fill(_ field: ReferenceWritableKeyPath<PersonalInfo, String>, _ value: String) {
                    guard person[keyPath: field].isBlank, !value.isBlank else { return }
                    person[keyPath: field] = value
                    filled = true
                }
                fill(\.fullName, personal.fullName)
                fill(\.headline, personal.headline)
                fill(\.email, personal.email)
                fill(\.phone, personal.phone)
                fill(\.location, personal.location)
                let known = Set(person.links.map { $0.url.lowercased() })
                let newLinks = personal.links.filter { !known.contains($0.url.lowercased()) }
                if !newLinks.isEmpty {
                    person.links += newLinks
                    filled = true
                }
                if filled {
                    person.status = .needsReview
                    person.addSource(source)
                    count += 1
                }
            } else {
                let person = PersonalInfo(
                    fullName: personal.fullName, headline: personal.headline, email: personal.email,
                    phone: personal.phone, location: personal.location, links: personal.links, status: .needsReview
                )
                person.sources = [source]
                context.insert(person)
                count += 1
            }
        }
        for item in items {
            switch item.action {
            case .skip:
                continue
            case .add:
                context.insert(item.record(source: source))
            case .merge:
                guard let id = item.matchID, let record = records[id] else { continue }
                record.merge(item, fields: item.picks, source: source)
            }
            count += 1
        }
        return count
    }
}
