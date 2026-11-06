//
//  Education.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Education: ReviewTracked {
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

    @Relationship(inverse: \Achievement.education)
    var achievements: [Achievement] = []

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
