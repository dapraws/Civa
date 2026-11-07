//
//  ResumeDocument.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// A resume's own content and formatting. It's a copy, not a reference: editing a resume never
/// changes the Career Profile or another resume, and the reverse holds too (FR-034, FR-041).
///
/// Fields added after the first release are Optional so resumes saved before them still decode.
nonisolated struct ResumeDocument: Codable, Hashable {
    var header = ResumeHeader()
    /// Shown under the header without a heading; edited with the header.
    var summary = ""
    /// In display order (FR-036 section order).
    var sections: [ResumeSection] = []
    var format = ResumeFormat()
    /// Personal Information as it was when the header was copied, so later changes can be
    /// suggested (FR-042).
    var headerSource: ResumeHeader?

    /// A blank resume with the usual sections, for "from scratch" (FR-030).
    static var blank: ResumeDocument {
        ResumeDocument(sections: [.experience, .education, .projects, .skills].map { ResumeSection(kind: $0) })
    }
}

nonisolated struct ResumeHeader: Codable, Hashable {
    var fullName = ""
    var headline = ""
    var email = ""
    var phone = ""
    var location = ""
    var links: [ProfileLink] = []
}

nonisolated struct ResumeSection: Codable, Hashable, Identifiable {
    /// Each kind offers a few standard headings that applicant tracking systems recognize (BR-001).
    enum Kind: String, Codable, CaseIterable {
        case experience, organizational, education, projects, achievements, certifications, skills

        /// The default heading.
        var heading: String { headingOptions[0] }

        /// Conventional names only; creative headings like "My Journey" can get a section skipped.
        var headingOptions: [String] {
            switch self {
            case .experience: [
                String(localized: "Experience"), String(localized: "Work Experience"),
                String(localized: "Professional Experience"), String(localized: "Employment History"),
            ]
            case .organizational: [
                String(localized: "Organizational Experience"), String(localized: "Leadership Experience"),
                String(localized: "Volunteer Experience"), String(localized: "Additional Experience"),
            ]
            case .education: [String(localized: "Education"), String(localized: "Education and Training")]
            case .projects: [
                String(localized: "Projects"), String(localized: "Personal Projects"), String(localized: "Selected Projects"),
            ]
            case .achievements: [
                String(localized: "Achievements"), String(localized: "Awards"), String(localized: "Honors and Awards"),
            ]
            case .certifications: [String(localized: "Certifications"), String(localized: "Licenses and Certifications")]
            case .skills: [
                String(localized: "Skills"), String(localized: "Technical Skills"), String(localized: "Skills and Tools"),
            ]
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var entries: [ResumeEntry] = []
    /// One of `kind.headingOptions`; nil is the default.
    var heading: String?

    /// The heading printed on the resume.
    var title: String { heading ?? kind.heading }
}

/// One item in a section. For skills, `title` is the category and `subtitle` the skills.
nonisolated struct ResumeEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    /// The profile record this came from, for Suggested Changes later (FR-042).
    var sourceID: UUID?
    var title = ""
    var subtitle = ""
    /// The dates as text. Set from `start`, `end`, and `isCurrent` when those are known; resumes
    /// made before them, or typed by hand, have only this.
    var dates = ""
    var bullets: [String] = []
    /// "Internship", printed after the subtitle when the resume shows employment types.
    var employmentType: String?
    var start: YearMonth?
    var end: YearMonth?
    var isCurrent: Bool?
    /// "Hybrid", printed after the subtitle when the resume shows work arrangements.
    var workArrangement: String?
    /// Education: "3.86/4.00", printed after the degree when the resume shows grades.
    var grade: String?
    /// Education.
    var thesis: String?
    /// Education.
    var coursework: [String]?
    /// Makes the title a link in the PDF when the resume links proof.
    var proofURL: String?
    /// The profile record as it read when copied here, so later changes to it can be suggested (FR-042).
    var sourceCopy: SourceCopy?

    /// Whether the dates come from pickers rather than typed text.
    var hasDateValues: Bool { start != nil || end != nil || isCurrent == true }

    /// The parts of an entry that come from the Career Profile.
    struct SourceCopy: Codable, Hashable {
        var title: String
        var subtitle: String
        var dates: String
        var bullets: [String]
        var employmentType: String?
        var workArrangement: String?
        var grade: String?
        var thesis: String?
        var coursework: [String]?
        var proofURL: String?
    }

    var asSourceCopy: SourceCopy {
        SourceCopy(
            title: title, subtitle: subtitle, dates: dates, bullets: bullets, employmentType: employmentType,
            workArrangement: workArrangement, grade: grade, thesis: thesis, coursework: coursework, proofURL: proofURL
        )
    }
}

/// Customization limited to what keeps the layout single-column and ATS-safe (FR-036).
/// Options added later are Optional, and nil reads as the default noted on each.
nonisolated struct ResumeFormat: Codable, Hashable {
    enum Font: String, Codable, CaseIterable {
        case helveticaNeue = "Helvetica Neue"
        case arial = "Arial"
        case georgia = "Georgia"
        case timesNewRoman = "Times New Roman"
    }

    enum Margins: String, Codable, CaseIterable {
        case narrow, normal, wide

        /// Points.
        var size: Double {
            switch self {
            case .narrow: 36
            case .normal: 54
            case .wide: 72
            }
        }
    }

    enum Accent: String, Codable, CaseIterable {
        case black, navy, teal, burgundy
    }

    enum Paper: String, Codable, CaseIterable {
        case a4, letter

        /// Points.
        var size: CGSize {
            switch self {
            case .a4: CGSize(width: 595.28, height: 841.89)
            case .letter: CGSize(width: 612, height: 792)
            }
        }
    }

    /// How months print: "Mar 2024", "March 2024", or "03/2024".
    enum DateStyle: String, Codable, CaseIterable {
        case short, long, numeric
    }

    var font = Font.helveticaNeue
    /// Body size in points; headings scale from it.
    var fontSize = 10.0
    var margins = Margins.normal
    var lineSpacing = 1.15
    /// Space above each section heading, in points.
    var sectionSpacing = 10.0
    /// Name and section headings only.
    var accent = Accent.black
    var paper = Paper.a4
    /// Off when nil.
    var showsEmploymentType: Bool?
    /// Off when nil.
    var showsWorkArrangement: Bool?
    /// On when nil.
    var showsGrade: Bool?
    /// On when nil: entry titles with a proof link open it from the PDF.
    var linksProof: Bool?
    /// `.short` when nil.
    var dateStyle: DateStyle?

    static let fontSizes = 9.0...12.0
    static let lineSpacings = [1.0, 1.15, 1.3]
    static let sectionSpacings = 6.0...18.0
}

nonisolated extension YearMonth {
    /// "Mar 2024", "March 2024", or "03/2024"; just the year when the month is unknown.
    func formatted(_ style: ResumeFormat.DateStyle, calendar: Calendar = .current) -> String {
        guard let month, (1...12).contains(month) else { return String(year) }
        return switch style {
        case .short: "\(calendar.shortMonthSymbols[month - 1]) \(year)"
        case .long: "\(calendar.monthSymbols[month - 1]) \(year)"
        case .numeric: String(format: "%02d/%d", month, year)
        }
    }

    /// "Mar 2024 – Present" in the given style.
    static func rangeText(
        start: YearMonth?, end: YearMonth?, isCurrent: Bool, style: ResumeFormat.DateStyle, calendar: Calendar = .current
    ) -> String {
        let startText = start?.formatted(style, calendar: calendar)
        let endText = isCurrent ? String(localized: "Present") : end?.formatted(style, calendar: calendar)
        return [startText, endText].compactMap(\.self).joined(separator: " – ")
    }
}

nonisolated extension Calendar {
    /// Resumes print English month names, whatever the Mac's language.
    // ponytail: fixed to English; follow a per-resume language once resumes have one.
    static let resume: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()
}

nonisolated extension ResumeEntry {
    /// The dates as printed: from the pickers in the resume's style, or the typed text.
    func datesText(_ style: ResumeFormat.DateStyle, calendar: Calendar = .resume) -> String {
        guard hasDateValues else { return dates }
        return YearMonth.rangeText(start: start, end: end, isCurrent: isCurrent == true, style: style, calendar: calendar)
    }
}
