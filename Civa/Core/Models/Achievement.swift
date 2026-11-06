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
    var details: String
    var customFields: [CustomField]
    var statusRaw: String
    var createdAt = Date.now
    var updatedAt = Date.now

    var experience: Experience?
    var project: Project?
    var education: Education?

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
