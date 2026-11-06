//
//  ProfileValues.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

// Model types are nonisolated: SwiftData uses them outside the main actor
// (the @Model conformance itself is nonisolated).

nonisolated enum ReviewStatus: String, Codable, CaseIterable {
    case confirmed
    case needsReview
}

/// Resume dates rarely carry a day. `month` is nil for year-only entries.
nonisolated struct YearMonth: Codable, Hashable, Comparable {
    var year: Int
    var month: Int?

    /// Sorts above every real date, so current and undated (new) records list first.
    static let distantFuture = YearMonth(year: .max)

    /// Year-only dates sort before any month of the same year.
    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month ?? 0) < (rhs.year, rhs.month ?? 0)
    }

    /// "Mar 2025", or "2025" when the month is unknown.
    func formatted(calendar: Calendar = .current) -> String {
        guard let month, (1...12).contains(month) else { return String(year) }
        return "\(calendar.shortMonthSymbols[month - 1]) \(year)"
    }

    /// "Mar 2024 – Present", "2019 – 2023", or whichever side is known.
    static func rangeText(
        start: YearMonth?,
        end: YearMonth?,
        isCurrent: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        let startText = start?.formatted(calendar: calendar)
        let endText = isCurrent ? String(localized: "Present") : end?.formatted(calendar: calendar)
        return [startText, endText].compactMap(\.self).joined(separator: " – ")
    }

    /// Sort key for newest-first lists.
    static func recency(start: YearMonth?, end: YearMonth?, isCurrent: Bool = false) -> YearMonth {
        isCurrent ? .distantFuture : (end ?? start ?? .distantFuture)
    }
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

/// A record the user creates and edits by hand.
nonisolated protocol EditableRecord: PersistentModel {
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    /// Shown in lists and in the "save changes" prompt.
    var displayTitle: String { get }
    /// True for profile records that haven't been confirmed (FR-015).
    var needsReview: Bool { get }
    /// Problems that block saving, keyed by the field they belong to. Empty when valid.
    func validationErrors() -> [PartialKeyPath<Self>: String]
}

nonisolated extension EditableRecord {
    var needsReview: Bool { false }
}

/// A Career Profile record. Status is stored as a raw string because enum comparisons
/// in `#Predicate` are unreliable.
nonisolated protocol ProfileRecord: EditableRecord {
    var statusRaw: String { get set }
}

nonisolated extension ProfileRecord {
    /// Unknown values read as `.needsReview` so they are never treated as confirmed facts.
    var status: ReviewStatus {
        get { ReviewStatus(rawValue: statusRaw) ?? .needsReview }
        set { statusRaw = newValue.rawValue }
    }

    var needsReview: Bool { status == .needsReview }
}

nonisolated extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

nonisolated extension YearMonth {
    /// True only when both dates are known and `end` comes before `start`.
    static func isReversed(start: YearMonth?, end: YearMonth?) -> Bool {
        guard let start, let end else { return false }
        return end < start
    }
}

nonisolated enum ValidationMessage {
    static var endBeforeStart: String { String(localized: "The end date can't be before the start date.") }
}
