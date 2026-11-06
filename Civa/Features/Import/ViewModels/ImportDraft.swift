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
        case .experience, .organizational: String(localized: "Organization")
        case .education: String(localized: "Institution")
        case .projects: String(localized: "Your Role")
        case .achievements, .certifications: String(localized: "Issuer")
        case .skills: String(localized: "Category")
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
    var isIncluded = true
    /// Matches a record already in the Career Profile, so it starts unchecked.
    var isDuplicate = false

    /// Something the parser couldn't fill and the user should look at.
    var needsCheck: Bool {
        switch category {
        case .skills: title.isBlank
        case .achievements, .certifications: title.isBlank
        case .experience, .organizational, .education, .projects:
            title.isBlank || subtitle.isBlank || (start == nil && !isCurrent)
        }
    }

    /// The record this becomes. Imported data is never confirmed automatically (FR-015, FR-020).
    func record() -> any PersistentModel {
        let details = bullets.joined(separator: "\n")
        switch category {
        case .experience, .organizational:
            return Experience(
                kind: category == .experience ? .professional : .organizational,
                organization: subtitle, role: title, location: location,
                start: start, end: end, isCurrent: isCurrent, impacts: bullets, status: .needsReview
            )
        case .education:
            return Education(
                institution: subtitle.isBlank ? title : subtitle, degree: subtitle.isBlank ? "" : title,
                location: location, start: start, end: end, details: details, status: .needsReview
            )
        case .projects:
            return Project(name: title, role: subtitle, start: start, end: end, impacts: bullets, status: .needsReview)
        case .achievements:
            return Achievement(title: title, issuer: subtitle, date: start, details: details, status: .needsReview)
        case .certifications:
            return Certification(name: title, issuer: subtitle, issued: start, status: .needsReview)
        case .skills:
            return Skill(name: title, category: subtitle, status: .needsReview)
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

    var includedCount: Int {
        items.count { $0.isIncluded } + (personal.isIncluded && !personal.isEmpty ? 1 : 0)
    }

    /// Unchecks items that match records already in the profile, by title and organization.
    mutating func markDuplicates(of existing: Set<String>) {
        for index in items.indices where existing.contains(Self.key(items[index])) {
            items[index].isDuplicate = true
            items[index].isIncluded = false
        }
    }

    static func key(_ item: ImportItem) -> String {
        key(item.category, item.title, item.category == .skills ? "" : item.subtitle)
    }

    static func key(_ category: ImportCategory, _ title: String, _ subtitle: String) -> String {
        [category.rawValue, title, subtitle].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.joined(separator: "|")
    }

    /// Adds the checked items as Needs Review records; the caller saves. An existing Personal
    /// Information record only gets its empty fields filled, so no value is overwritten.
    /// Returns how many records were added or changed.
    @discardableResult
    func add(to context: ModelContext, existing person: PersonalInfo?) -> Int {
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
                    count += 1
                }
            } else {
                context.insert(PersonalInfo(
                    fullName: personal.fullName, headline: personal.headline, email: personal.email,
                    phone: personal.phone, location: personal.location, links: personal.links, status: .needsReview
                ))
                count += 1
            }
        }
        for item in items where item.isIncluded {
            context.insert(item.record())
            count += 1
        }
        return count
    }
}
