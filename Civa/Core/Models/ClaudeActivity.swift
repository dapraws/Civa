//
//  ClaudeActivity.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// What Claude may read or suggest changes to, each switched on separately (FR-071).
nonisolated enum ClaudeCategory: String, Codable, CaseIterable, Identifiable {
    case personal, experience, education, projects, recognition, skills, resumes, applications

    var id: Self { self }

    var title: String {
        switch self {
        case .personal: String(localized: "Personal Information")
        case .experience: String(localized: "Experience")
        case .education: String(localized: "Education")
        case .projects: String(localized: "Projects")
        case .recognition: String(localized: "Achievements and Certifications")
        case .skills: String(localized: "Skills")
        case .resumes: String(localized: "Resumes")
        case .applications: String(localized: "Applications")
        }
    }
}

/// One entry in the audit log (FR-074): a read, a refusal, a suggestion, or a decision on one.
@Model
nonisolated final class ClaudeActivity {
    enum Kind: String, Codable {
        case read, denied, suggested, approved, rejected
    }

    var id = UUID()
    var date = Date.now
    var kindRaw: String
    /// The tool Claude called.
    var tool: String
    /// Raw value of `ClaudeCategory`; empty for tools outside a category.
    var categoryRaw: String
    /// "Read 6 experience records".
    var summary: String
    /// What was read or proposed, such as the record titles.
    var detail: String

    var kind: Kind { Kind(rawValue: kindRaw) ?? .read }
    var category: ClaudeCategory? { ClaudeCategory(rawValue: categoryRaw) }

    init(kind: Kind, tool: String, category: ClaudeCategory?, summary: String, detail: String = "") {
        self.kindRaw = kind.rawValue
        self.tool = tool
        self.categoryRaw = category?.rawValue ?? ""
        self.summary = summary
        self.detail = detail
    }
}
