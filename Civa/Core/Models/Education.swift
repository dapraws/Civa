//
//  Education.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Education: ProfileRecord {
    var id = UUID()
    var institution: String
    var degree: String
    var fieldOfStudy: String
    var location: String
    var start: YearMonth?
    var end: YearMonth?
    var grade: String
    var details: String
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.education)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    @Relationship(inverse: \Achievement.education)
    var achievements: [Achievement] = []

    var displayTitle: String {
        institution.isBlank ? String(localized: "New Education") : institution
    }

    func validationErrors() -> [PartialKeyPath<Education>: String] {
        var errors: [PartialKeyPath<Education>: String] = [:]
        if institution.isBlank { errors[\.institution] = String(localized: "Enter an institution.") }
        if YearMonth.isReversed(start: start, end: end) { errors[\.end] = ValidationMessage.endBeforeStart }
        return errors
    }

    init(
        institution: String,
        degree: String = "",
        fieldOfStudy: String = "",
        location: String = "",
        start: YearMonth? = nil,
        end: YearMonth? = nil,
        grade: String = "",
        details: String = "",
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.institution = institution
        self.degree = degree
        self.fieldOfStudy = fieldOfStudy
        self.location = location
        self.start = start
        self.end = end
        self.grade = grade
        self.details = details
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
