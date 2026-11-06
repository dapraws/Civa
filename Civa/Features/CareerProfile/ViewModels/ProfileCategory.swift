//
//  ProfileCategory.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// The six Career Profile categories, in product order (FR-010).
enum ProfileCategory: String, CaseIterable, Identifiable {
    case personal
    case professional
    case education
    case organizational
    case projects
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .personal: String(localized: "Personal Information")
        case .professional: String(localized: "Professional Experience")
        case .education: String(localized: "Education")
        case .organizational: String(localized: "Organizational Experience")
        case .projects: String(localized: "Projects")
        case .other: String(localized: "Other Information")
        }
    }

    /// Fits the toolbar's segmented control.
    var shortTitle: String {
        switch self {
        case .personal: String(localized: "Personal")
        case .professional: String(localized: "Professional")
        case .education: String(localized: "Education")
        case .organizational: String(localized: "Organizational")
        case .projects: String(localized: "Projects")
        case .other: String(localized: "Other")
        }
    }
}
