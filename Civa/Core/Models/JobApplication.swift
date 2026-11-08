//
//  JobApplication.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// FR-061, in pipeline order.
nonisolated enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case wishlist
    case applied
    case interview
    case assessment
    case offer
    case rejected
    case withdrawn

    var id: Self { self }

    var title: String {
        switch self {
        case .wishlist: String(localized: "Wishlist")
        case .applied: String(localized: "Applied")
        case .interview: String(localized: "Interview")
        case .assessment: String(localized: "Assessment")
        case .offer: String(localized: "Offer")
        case .rejected: String(localized: "Rejected")
        case .withdrawn: String(localized: "Withdrawn")
        }
    }
}

/// A job the user is tracking (FR-060), optionally linked to the resume sent for it.
@Model
nonisolated final class JobApplication: EditableRecord {
    var id = UUID()
    var company: String
    var position: String
    var jobDescription: String
    /// Optional: a wishlist entry has no application date yet.
    var applicationDate: Date?
    /// Raw string because enum comparisons in `#Predicate` are unreliable.
    var statusRaw: String
    /// The resume sent for this job. Cleared if that resume is deleted.
    var resume: Resume?
    /// Job posting, cover letter, offer letter. Deleting the application keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.applications)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .wishlist }
        set { statusRaw = newValue.rawValue }
    }

    var displayTitle: String {
        [position, company].first { !$0.isBlank } ?? String(localized: "New Application")
    }

    func validationErrors() -> [PartialKeyPath<JobApplication>: String] {
        var errors: [PartialKeyPath<JobApplication>: String] = [:]
        if position.isBlank { errors[\.position] = String(localized: "Enter a position.") }
        if company.isBlank { errors[\.company] = String(localized: "Enter a company.") }
        return errors
    }

    /// Filter for one status, or nil for all applications.
    static func withStatus(_ status: ApplicationStatus?) -> Predicate<JobApplication>? {
        guard let raw = status?.rawValue else { return nil }
        return #Predicate { $0.statusRaw == raw }
    }

    init(
        company: String,
        position: String,
        jobDescription: String = "",
        applicationDate: Date? = nil,
        status: ApplicationStatus = .wishlist
    ) {
        self.company = company
        self.position = position
        self.jobDescription = jobDescription
        self.applicationDate = applicationDate
        self.statusRaw = status.rawValue
    }
}
