//
//  AppSection.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Main sidebar navigation (FR-003).
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case careerProfile
    case documents
    case resumes
    case applications
    case aiActivity
    case settings

    var id: Self { self }

    /// The sidebar's sections. AI Activity appears once Claude Desktop is set up (FR-075).
    static func visible(claudeEnabled: Bool) -> [AppSection] {
        allCases.filter { $0 != .aiActivity || claudeEnabled }
    }

    var title: String {
        switch self {
        case .dashboard: String(localized: "Dashboard")
        case .careerProfile: String(localized: "Career Profile")
        case .documents: String(localized: "Documents")
        case .resumes: String(localized: "Resumes")
        case .applications: String(localized: "Applications")
        case .aiActivity: String(localized: "AI Activity")
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .careerProfile: "person.text.rectangle"
        case .documents: "doc.on.doc"
        case .resumes: "doc.text"
        case .applications: "tray.full"
        case .aiActivity: "sparkles"
        case .settings: "gearshape"
        }
    }
}
