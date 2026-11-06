//
//  ProfileValues.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

// Model types are nonisolated: SwiftData uses them outside the main actor
// (the @Model conformance itself is nonisolated).

nonisolated enum ReviewStatus: String, Codable, CaseIterable {
    case confirmed
    case needsReview
}

/// Resume dates rarely carry a day. `month` is nil for year-only entries.
nonisolated struct YearMonth: Codable, Hashable {
    var year: Int
    var month: Int?
}

nonisolated struct CustomField: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var value: String
}

nonisolated struct ProfileLink: Codable, Hashable, Identifiable {
    var id = UUID()
    var label: String
    var url: String
}

/// Records store status as a raw string because enum comparisons in `#Predicate` are unreliable.
nonisolated protocol ReviewTracked: AnyObject {
    var statusRaw: String { get set }
}

nonisolated extension ReviewTracked {
    /// Unknown values read as `.needsReview` so they are never treated as confirmed facts.
    var status: ReviewStatus {
        get { ReviewStatus(rawValue: statusRaw) ?? .needsReview }
        set { statusRaw = newValue.rawValue }
    }
}
