//
//  Experience.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

nonisolated enum ExperienceKind: String, Codable, CaseIterable {
    case professional
    case organizational
}

/// Professional and Organizational Experience share this model; the categories are filtered by `kind`.
@Model
nonisolated final class Experience: ProfileRecord {
    var id = UUID()
    var kindRaw: String
    var organization: String
    var role: String
    var location: String
    var start: YearMonth?
    var end: YearMonth?
    var isCurrent: Bool
    var details: String
    /// Results of the work (PRODUCT §4.3). Formal recognition belongs in `achievements`.
    var impacts: [String]
    var customFields: [CustomField]
    var statusRaw: String
    var createdAt = Date.now
    var updatedAt = Date.now

    @Relationship(inverse: \Skill.experiences)
    var skills: [Skill] = []

    @Relationship(inverse: \Achievement.experience)
    var achievements: [Achievement] = []

    var kind: ExperienceKind {
        get { ExperienceKind(rawValue: kindRaw) ?? .professional }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        [role, organization].first { !$0.isBlank } ?? String(localized: "New Experience")
    }

    func validationErrors() -> [PartialKeyPath<Experience>: String] {
        var errors: [PartialKeyPath<Experience>: String] = [:]
        if role.isBlank { errors[\.role] = String(localized: "Enter a role.") }
        if organization.isBlank {
            errors[\.organization] = kind == .professional
                ? String(localized: "Enter a company.")
                : String(localized: "Enter an organization.")
        }
        if !isCurrent, YearMonth.isReversed(start: start, end: end) { errors[\.end] = ValidationMessage.endBeforeStart }
        return errors
    }

    init(
        kind: ExperienceKind,
        organization: String,
        role: String,
        location: String = "",
        start: YearMonth? = nil,
        end: YearMonth? = nil,
        isCurrent: Bool = false,
        details: String = "",
        impacts: [String] = [],
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.kindRaw = kind.rawValue
        self.organization = organization
        self.role = role
        self.location = location
        self.start = start
        self.end = end
        self.isCurrent = isCurrent
        self.details = details
        self.impacts = impacts
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
