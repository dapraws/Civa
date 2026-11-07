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

/// LinkedIn's employment types, so imports and profiles use the same words.
nonisolated enum EmploymentType: String, Codable, TitledOption {
    case fullTime, partTime, selfEmployed, freelance, contract, internship, apprenticeship, seasonal

    var id: Self { self }

    var title: String {
        switch self {
        case .fullTime: String(localized: "Full-time")
        case .partTime: String(localized: "Part-time")
        case .selfEmployed: String(localized: "Self-employed")
        case .freelance: String(localized: "Freelance")
        case .contract: String(localized: "Contract")
        case .internship: String(localized: "Internship")
        case .apprenticeship: String(localized: "Apprenticeship")
        case .seasonal: String(localized: "Seasonal")
        }
    }

    /// Finds a type named in text, in English or Indonesian: "Full-time", "Magang", "Kontrak".
    static func find(in text: String) -> EmploymentType? {
        let lower = text.lowercased()
        let words: [(EmploymentType, [String])] = [
            (.fullTime, ["full-time", "full time", "fulltime", "penuh waktu"]),
            (.partTime, ["part-time", "part time", "parttime", "paruh waktu"]),
            (.selfEmployed, ["self-employed", "self employed", "wiraswasta"]),
            (.freelance, ["freelance", "freelancer", "lepas", "pekerja lepas"]),
            (.contract, ["contract", "kontrak"]),
            (.internship, ["internship", "magang"]),
            (.apprenticeship, ["apprenticeship"]),
            (.seasonal, ["seasonal", "musiman"]),
        ]
        return words.first { _, names in names.contains { lower == $0 } }?.0
    }
}

/// Where the work happened.
nonisolated enum WorkArrangement: String, Codable, TitledOption {
    case onSite, hybrid, remote

    var id: Self { self }

    var title: String {
        switch self {
        case .onSite: String(localized: "On-site")
        case .hybrid: String(localized: "Hybrid")
        case .remote: String(localized: "Remote")
        }
    }
}

/// What kind of organizational experience this is.
nonisolated enum OrganizationType: String, Codable, TitledOption {
    case organization, leadership, program, community, volunteer, assistant

    var id: Self { self }

    var title: String {
        switch self {
        case .organization: String(localized: "Organization")
        case .leadership: String(localized: "Leadership")
        case .program: String(localized: "Program or Bootcamp")
        case .community: String(localized: "Community")
        case .volunteer: String(localized: "Volunteer")
        case .assistant: String(localized: "Lab or Teaching Assistant")
        }
    }
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
    /// Raw value of `EmploymentType`; empty when not set. Professional experience only.
    var employmentTypeRaw = ""
    /// Raw value of `WorkArrangement`; empty when not set.
    var workArrangementRaw = ""
    /// Raw value of `OrganizationType`; empty when not set. Organizational experience only.
    var organizationTypeRaw = ""
    /// A distinction from the role, like "Graduate with Distinction". Organizational experience only.
    var recognition = ""
    /// A link that proves the role, like a certificate or recommendation.
    var proofURL = ""
    var details: String
    /// Results of the work (PRODUCT §4.3). Formal recognition belongs in `achievements`.
    var impacts: [String]
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.experience)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    @Relationship(inverse: \Skill.experiences)
    var skills: [Skill] = []

    @Relationship(inverse: \Achievement.experience)
    var achievements: [Achievement] = []

    var employmentType: EmploymentType? {
        get { EmploymentType(rawValue: employmentTypeRaw) }
        set { employmentTypeRaw = newValue?.rawValue ?? "" }
    }

    var workArrangement: WorkArrangement? {
        get { WorkArrangement(rawValue: workArrangementRaw) }
        set { workArrangementRaw = newValue?.rawValue ?? "" }
    }

    var organizationType: OrganizationType? {
        get { OrganizationType(rawValue: organizationTypeRaw) }
        set { organizationTypeRaw = newValue?.rawValue ?? "" }
    }

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
        if !proofURL.isBlank, URL.webLink(proofURL) == nil { errors[\.proofURL] = ValidationMessage.invalidLink }
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
