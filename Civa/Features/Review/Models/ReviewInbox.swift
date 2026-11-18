//
//  ReviewInbox.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Foundation

/// Everything waiting for the user in one list: Claude's suggestions and drafts, then Career
/// Profile records that need review. The sidebar badge and the Dock badge show its count.
struct ReviewInbox {
    /// A record awaiting review, with where it opens in the Career Profile.
    struct Record: Identifiable, Hashable {
        let id: UUID
        let title: String
        let category: ProfileCategory
        /// For Other Information: achievements, certifications, or skills.
        let otherKind: String?
        let kindTitle: String
    }

    let suggestions: [ClaudeProposal]
    let records: [Record]

    var count: Int { suggestions.count + records.count }

    /// `proposals` are pending ones; records that don't need review are left out.
    init(proposals: [ClaudeProposal], records: [any ProfileRecord]) {
        suggestions = proposals.sorted { $0.createdAt > $1.createdAt }
        self.records = records.filter(\.needsReview).compactMap(Self.record)
    }

    private static func record(_ record: any ProfileRecord) -> Record? {
        switch record {
        case let person as PersonalInfo:
            Record(id: person.id, title: person.displayTitle, category: .personal, otherKind: nil, kindTitle: ProfileCategory.personal.title)
        case let experience as Experience:
            Record(
                id: experience.id, title: experience.displayTitle,
                category: experience.kind == .professional ? .professional : .organizational, otherKind: nil,
                kindTitle: (experience.kind == .professional ? ProfileCategory.professional : .organizational).title
            )
        case let education as Education:
            Record(id: education.id, title: education.displayTitle, category: .education, otherKind: nil, kindTitle: ProfileCategory.education.title)
        case let project as Project:
            Record(id: project.id, title: project.displayTitle, category: .projects, otherKind: nil, kindTitle: ProfileCategory.projects.title)
        case let achievement as Achievement:
            Record(id: achievement.id, title: achievement.displayTitle, category: .other, otherKind: "achievements", kindTitle: String(localized: "Achievement"))
        case let certification as Certification:
            Record(id: certification.id, title: certification.displayTitle, category: .other, otherKind: "certifications", kindTitle: String(localized: "Certification"))
        case let skill as Skill:
            Record(id: skill.id, title: skill.displayTitle, category: .other, otherKind: "skills", kindTitle: String(localized: "Skill"))
        default:
            nil
        }
    }
}
