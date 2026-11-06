//
//  Project.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Project: ProfileRecord {
    var id = UUID()
    var name: String
    var role: String
    var url: String
    var start: YearMonth?
    var end: YearMonth?
    var details: String
    var impacts: [String]
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.project)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    @Relationship(inverse: \Skill.projects)
    var skills: [Skill] = []

    @Relationship(inverse: \Achievement.project)
    var achievements: [Achievement] = []

    var displayTitle: String {
        name.isBlank ? String(localized: "New Project") : name
    }

    func validationErrors() -> [PartialKeyPath<Project>: String] {
        var errors: [PartialKeyPath<Project>: String] = [:]
        if name.isBlank { errors[\.name] = String(localized: "Enter a project name.") }
        if YearMonth.isReversed(start: start, end: end) { errors[\.end] = ValidationMessage.endBeforeStart }
        return errors
    }

    init(
        name: String,
        role: String = "",
        url: String = "",
        start: YearMonth? = nil,
        end: YearMonth? = nil,
        details: String = "",
        impacts: [String] = [],
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.name = name
        self.role = role
        self.url = url
        self.start = start
        self.end = end
        self.details = details
        self.impacts = impacts
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
