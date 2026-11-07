//
//  Skill.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

nonisolated enum SkillType: String, Codable, TitledOption {
    case hard, soft

    var id: Self { self }

    var title: String {
        switch self {
        case .hard: String(localized: "Hard Skill")
        case .soft: String(localized: "Soft Skill")
        }
    }
}

/// No `#Unique` on `name`: SwiftData treats a unique conflict as an upsert and would silently merge records.
/// Duplicate detection is app logic (FR-024).
@Model
nonisolated final class Skill: ProfileRecord {
    var id = UUID()
    var name: String
    var category: String
    /// Optional by design (FR-014).
    var proficiency: String?
    /// Raw value of `SkillType`; empty when not set.
    var typeRaw = ""
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?
    var createdAt = Date.now
    var updatedAt = Date.now

    /// Evidence for the skill (PRODUCT §4.4).
    var experiences: [Experience] = []
    var projects: [Project] = []

    var type: SkillType? {
        get { SkillType(rawValue: typeRaw) }
        set { typeRaw = newValue?.rawValue ?? "" }
    }

    var displayTitle: String {
        name.isBlank ? String(localized: "New Skill") : name
    }

    func validationErrors() -> [PartialKeyPath<Skill>: String] {
        name.isBlank ? [\.name: String(localized: "Enter a skill name.")] : [:]
    }

    init(
        name: String,
        category: String = "",
        proficiency: String? = nil,
        status: ReviewStatus = .confirmed
    ) {
        self.name = name
        self.category = category
        self.proficiency = proficiency
        self.statusRaw = status.rawValue
    }
}
