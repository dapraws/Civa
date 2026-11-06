//
//  ResumeCheck.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Problems worth a look before export (FR-037). The user can always export anyway.
enum ResumeCheck {
    /// Most recruiters expect one or two pages.
    static let pageLimit = 2

    static func issues(for document: ResumeDocument, pageCount: Int, unconfirmedSources: Set<UUID>) -> [String] {
        var issues: [String] = []
        let header = document.header
        if header.fullName.isBlank {
            issues.append(String(localized: "Add your name in Header."))
        }
        if header.email.isBlank && header.phone.isBlank {
            issues.append(String(localized: "Add an email address or phone number so employers can reach you."))
        }

        let entries = document.sections.flatMap { section in section.entries.map { (section, $0) } }
        if entries.isEmpty {
            issues.append(String(localized: "Add at least one entry in Sections."))
        }
        for (section, entry) in entries {
            if section.kind == .skills, entry.subtitle.isBlank {
                issues.append(String(localized: "\(section.kind.heading) has a line without any skills."))
            } else if section.kind != .skills, entry.title.isBlank {
                issues.append(String(localized: "\(section.kind.heading) has an entry without a title."))
            }
            if let source = entry.sourceID, unconfirmedSources.contains(source) {
                let name = entry.title.isBlank ? section.kind.heading : entry.title
                issues.append(String(localized: "“\(name)” comes from profile information that still needs review."))
            }
        }

        if pageCount > pageLimit {
            issues.append(String(localized: "The resume is \(pageCount) pages. Most recruiters expect one or two."))
        }
        return issues
    }

    /// IDs of profile records still marked Needs Review.
    static func unconfirmedSources(in context: ModelContext) -> Set<UUID> {
        let raw = ReviewStatus.needsReview.rawValue
        func ids<M: ProfileRecord>(_: M.Type) -> [UUID] where M.ID == UUID {
            ((try? context.fetch(FetchDescriptor<M>())) ?? []).filter { $0.statusRaw == raw }.map(\.id)
        }
        return Set(
            ids(PersonalInfo.self) + ids(Experience.self) + ids(Education.self) + ids(Project.self)
                + ids(Achievement.self) + ids(Certification.self) + ids(Skill.self)
        )
    }
}
