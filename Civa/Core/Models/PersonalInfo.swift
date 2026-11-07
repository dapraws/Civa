//
//  PersonalInfo.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class PersonalInfo: ProfileRecord {
    var id = UUID()
    var fullName: String
    var headline: String
    /// A few sentences on who you are; resumes start their header with it.
    var summary = ""
    var email: String
    var phone: String
    var location: String
    var links: [ProfileLink]
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    var displayTitle: String {
        fullName.isBlank ? String(localized: "Personal Information") : fullName
    }

    func validationErrors() -> [PartialKeyPath<PersonalInfo>: String] {
        var errors: [PartialKeyPath<PersonalInfo>: String] = [:]
        if fullName.isBlank { errors[\.fullName] = String(localized: "Enter your full name.") }
        if !email.isBlank, !email.contains("@") { errors[\.email] = String(localized: "Enter a valid email address.") }
        return errors
    }

    init(
        fullName: String,
        headline: String = "",
        email: String = "",
        phone: String = "",
        location: String = "",
        links: [ProfileLink] = [],
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.fullName = fullName
        self.headline = headline
        self.email = email
        self.phone = phone
        self.location = location
        self.links = links
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
