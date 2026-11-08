//
//  Certification.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Certification: ProfileRecord {
    var id = UUID()
    var name: String
    var issuer: String
    var issued: YearMonth?
    var expires: YearMonth?
    var credentialID: String
    var credentialURL: String
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.certifications)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    var displayTitle: String {
        name.isBlank ? String(localized: "New Certification") : name
    }

    func validationErrors() -> [PartialKeyPath<Certification>: String] {
        var errors: [PartialKeyPath<Certification>: String] = [:]
        if name.isBlank { errors[\.name] = String(localized: "Enter a certification name.") }
        if YearMonth.isReversed(start: issued, end: expires) {
            errors[\.expires] = String(localized: "The expiry date can't be before the issue date.")
        }
        if !credentialURL.isBlank, URL.webLink(credentialURL) == nil { errors[\.credentialURL] = ValidationMessage.invalidLink }
        return errors
    }

    init(
        name: String,
        issuer: String = "",
        issued: YearMonth? = nil,
        expires: YearMonth? = nil,
        credentialID: String = "",
        credentialURL: String = "",
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.name = name
        self.issuer = issuer
        self.issued = issued
        self.expires = expires
        self.credentialID = credentialID
        self.credentialURL = credentialURL
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
