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
    case resumes
    case applications
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: String(localized: "Dashboard")
        case .careerProfile: String(localized: "Career Profile")
        case .resumes: String(localized: "Resumes")
        case .applications: String(localized: "Applications")
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .careerProfile: "person.text.rectangle"
        case .resumes: "doc.text"
        case .applications: "tray.full"
        case .settings: "gearshape"
        }
    }
}
