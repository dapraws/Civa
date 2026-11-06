//
//  Project.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Project: ReviewTracked {
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

    @Relationship(inverse: \Skill.projects)
    var skills: [Skill] = []

    @Relationship(inverse: \Achievement.project)
    var achievements: [Achievement] = []

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
