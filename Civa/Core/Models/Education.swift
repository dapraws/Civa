//
//  Education.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Indonesian levels first-class: SMA/SMK, D3, D4, S1, S2, S3.
nonisolated enum DegreeLevel: String, Codable, TitledOption {
    case highSchool, diploma, appliedBachelor, bachelor, master, doctorate

    var id: Self { self }

    var title: String {
        switch self {
        case .highSchool: String(localized: "High School (SMA/SMK)")
        case .diploma: String(localized: "Diploma (D3)")
        case .appliedBachelor: String(localized: "Applied Bachelor (D4)")
        case .bachelor: String(localized: "Bachelor's (S1)")
        case .master: String(localized: "Master's (S2)")
        case .doctorate: String(localized: "Doctorate (S3)")
        }
    }
}

/// What a grade is called. Not every school grades with a GPA.
nonisolated enum GradeLabel: String, Codable, TitledOption {
    case gpa, ipk, score

    var id: Self { self }

    var title: String {
        switch self {
        case .gpa: String(localized: "GPA")
        case .ipk: String(localized: "IPK")
        case .score: String(localized: "Score")
        }
    }
}

/// A grade out of a maximum: 3.86 out of 4.00, or 91.4 out of 100.
nonisolated struct Grade: Equatable {
    var value: Double
    var scale: Double

    /// Maximums offered without typing; any other positive number works too.
    static let commonScales: [Double] = [4, 3, 5, 10, 100]

    /// "3.86 / 4.00" for small scales, "91.4 / 100" for large ones.
    func formatted(locale: Locale = .current, separator: String = " / ") -> String {
        "\(value.formatted(style(locale)))\(separator)\(scaleText(locale: locale))"
    }

    /// The maximum alone: "4.00", "100".
    func scaleText(locale: Locale = .current) -> String {
        scale.formatted(style(locale))
    }

    private func style(_ locale: Locale) -> FloatingPointFormatStyle<Double> {
        .number.locale(locale).precision(scale <= 5 ? .fractionLength(2) : .fractionLength(0...2))
    }

    /// Reads grades typed as text: "3.86 / 4.00", "IPK 3,5 dari 4", "91.4 out of 100", or a bare "3.7".
    /// A bare number is taken as out of 4 up to 4, and out of 100 above 10; anything else is nil.
    static func parse(_ text: String) -> (grade: Grade, label: GradeLabel?)? {
        let pattern = /^\s*(?<label>gpa|ipk|score|nilai)?\s*:?\s*(?<value>\d+(?:[.,]\d+)?)\s*(?:(?:\/|of|out of|dari)\s*(?<scale>\d+(?:[.,]\d+)?))?\s*$/
            .ignoresCase()
        guard let match = text.wholeMatch(of: pattern),
              let value = Double(match.value.replacing(",", with: ".")) else { return nil }
        let label: GradeLabel? = switch match.label?.lowercased() {
        case "gpa": .gpa
        case "ipk": .ipk
        case "score", "nilai": .score
        default: nil
        }
        let scale: Double
        if let typed = match.scale {
            guard let typedScale = Double(typed.replacing(",", with: ".")) else { return nil }
            scale = typedScale
        } else if value <= 4 {
            scale = 4
        } else if value > 10, value <= 100 {
            scale = 100
        } else {
            return nil
        }
        guard scale > 0, value <= scale else { return nil }
        return (Grade(value: value, scale: scale), label)
    }
}

@Model
nonisolated final class Education: ProfileRecord {
    var id = UUID()
    var institution: String
    var degree: String
    var fieldOfStudy: String
    var location: String
    var start: YearMonth?
    var end: YearMonth?
    /// Raw value of `DegreeLevel`; empty when not set.
    var degreeLevelRaw = ""
    var gradeValue: Double?
    var gradeScale: Double = 4
    var gradeLabelRaw = GradeLabel.gpa.rawValue
    /// A grade typed as text that couldn't be read as a number out of a maximum. Empty once converted.
    var grade: String
    var thesis = ""
    var coursework: [String] = []
    /// Like "Cum Laude" or "Dean's List".
    var honors = ""
    /// A link that proves the degree, like a diploma or transcript.
    var proofURL = ""
    var details: String
    var customFields: [CustomField]
    var statusRaw: String
    /// Where the information came from (FR-024).
    var sources: [RecordSource] = []
    /// Set when this was added from an import despite matching this record (FR-024).
    var possibleDuplicateOf: UUID?

    /// Supporting documents (FR-022). Deleting this record keeps them, unlinked.
    @Relationship(deleteRule: .nullify, inverse: \SupportingDocument.education)
    var documents: [SupportingDocument] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    @Relationship(inverse: \Achievement.education)
    var achievements: [Achievement] = []

    var degreeLevel: DegreeLevel? {
        get { DegreeLevel(rawValue: degreeLevelRaw) }
        set { degreeLevelRaw = newValue?.rawValue ?? "" }
    }

    var gradeLabel: GradeLabel {
        get { GradeLabel(rawValue: gradeLabelRaw) ?? .gpa }
        set { gradeLabelRaw = newValue.rawValue }
    }

    /// The grade as a number out of a maximum; nil when there is none.
    var numericGrade: Grade? {
        gradeValue.map { Grade(value: $0, scale: gradeScale) }
    }

    /// "GPA 3.86 / 4.00", or the grade as it was typed.
    var gradeText: String {
        if let numericGrade { return "\(gradeLabel.title) \(numericGrade.formatted())" }
        return grade
    }

    /// Moves a text grade into the number and scale when it can be read. Returns true when it did.
    @discardableResult
    func convertTextGrade() -> Bool {
        guard gradeValue == nil, let parsed = Grade.parse(grade) else { return false }
        gradeValue = parsed.grade.value
        gradeScale = parsed.grade.scale
        if let label = parsed.label { gradeLabel = label }
        grade = ""
        return true
    }

    var displayTitle: String {
        institution.isBlank ? String(localized: "New Education") : institution
    }

    func validationErrors() -> [PartialKeyPath<Education>: String] {
        var errors: [PartialKeyPath<Education>: String] = [:]
        if institution.isBlank { errors[\.institution] = String(localized: "Enter an institution.") }
        if YearMonth.isReversed(start: start, end: end) { errors[\.end] = ValidationMessage.endBeforeStart }
        if gradeScale <= 0 {
            errors[\.gradeScale] = String(localized: "The maximum grade must be more than 0.")
        } else if let gradeValue, gradeValue < 0 || gradeValue > gradeScale {
            errors[\.gradeValue] = String(localized: "The grade must be between 0 and \(gradeScale.formatted()).")
        }
        if !proofURL.isBlank, URL.webLink(proofURL) == nil { errors[\.proofURL] = ValidationMessage.invalidLink }
        return errors
    }

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
