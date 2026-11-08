//
//  Achievement.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Formal recognition (PRODUCT §4.3), optionally linked to the record it came from.
@Model
nonisolated final class Achievement: ProfileRecord {
    var id = UUID()
    var title: String
    var issuer: String
    var date: YearMonth?
    /// Rank or result, like "1st Place" or "Finalist".
    var placement = ""
    /// A link that proves the award, like an announcement or certificate.
    var proofURL = ""
    var details: String
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.achievements)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    var experience: Experience?
    var project: Project?
    var education: Education?

    var displayTitle: String {
        title.isBlank ? String(localized: "New Achievement") : title
    }

    func validationErrors() -> [PartialKeyPath<Achievement>: String] {
        var errors: [PartialKeyPath<Achievement>: String] = [:]
        if title.isBlank { errors[\.title] = String(localized: "Enter a title.") }
        if !proofURL.isBlank, URL.webLink(proofURL) == nil { errors[\.proofURL] = ValidationMessage.invalidLink }
        return errors
    }

    init(
        title: String,
        issuer: String = "",
        date: YearMonth? = nil,
        details: String = "",
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.title = title
        self.issuer = issuer
        self.date = date
        self.details = details
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
