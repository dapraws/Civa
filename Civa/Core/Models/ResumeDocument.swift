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
    /// Claude wrote the summary and it hasn't been edited since; the editor tags it.
    var claudeTouchedSummary: Bool?

    /// A blank resume with the usual sections, for "from scratch" (FR-030).
    static var blank: ResumeDocument {
        ResumeDocument(sections: [.experience, .education, .projects, .skills].map { ResumeSection(kind: $0) })
    }

    /// A manual edit to an entry. Changing it clears its Claude tag; writing the same value back,
    /// as a field can on focus, keeps it.
    mutating func updateEntry(_ id: UUID, to new: ResumeEntry) {
        guard let position = entryPosition(id) else { return }
        let old = sections[position.section].entries[position.entry]
        guard new != old else { return }
        var new = new
        if new.claudeTouched == old.claudeTouched { new.claudeTouched = nil }
        sections[position.section].entries[position.entry] = new
    }

    /// A manual edit to the summary; clears its Claude tag when the text changes.
    mutating func setSummary(_ text: String) {
        guard text != summary else { return }
        summary = text
        claudeTouchedSummary = nil
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
    /// "Jakarta, Indonesia". The subtitle also ends with it; templates that print the location
    /// on the right take it off the subtitle there.
    var location: String?
    /// The profile record as it read when copied here, so later changes to it can be suggested (FR-042).
    var sourceCopy: SourceCopy?
    /// Claude wrote part of this entry and it hasn't been edited since; the editor tags it.
    var claudeTouched: Bool?
    /// Details the user showed or hid on this entry with the eye, by `Detail` raw value.
    /// A detail with no choice follows its default.
    var visibility: [String: Bool]?

    /// Optional details each entry can show or hide on its own.
    enum Detail: String, CaseIterable {
        case employmentType, workArrangement, location, grade, thesis, coursework, proof

        /// Before the eye, employment types, work arrangements, and grades were switched for the
        /// whole resume; those choices stay the default, so older resumes print as they did.
        func shownByDefault(in format: ResumeFormat) -> Bool {
            switch self {
            case .employmentType: format.showsEmploymentType == true
            case .workArrangement: format.showsWorkArrangement == true
            case .grade: format.showsGrade != false
            case .location, .thesis, .coursework, .proof: true
            }
        }
    }

    func shows(_ detail: Detail, in format: ResumeFormat) -> Bool {
        visibility?[detail.rawValue] ?? detail.shownByDefault(in: format)
    }

    mutating func setShows(_ detail: Detail, _ isShown: Bool) {
        var visibility = self.visibility ?? [:]
        visibility[detail.rawValue] = isShown
        self.visibility = visibility
    }

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
        /// Skill lines: the skills the line was built from, by record id, with their names then.
        var skills: [UUID: String]?
        var location: String?

        /// Whether the profile still reads as this copy. Copies made before locations were kept
        /// separately have none; their subtitle already carries it, so it isn't compared.
        func matches(_ old: SourceCopy) -> Bool {
            var new = self
            if old.location == nil { new.location = nil }
            return new == old
        }
    }

    var asSourceCopy: SourceCopy {
        SourceCopy(
            title: title, subtitle: subtitle, dates: dates, bullets: bullets, employmentType: employmentType,
            workArrangement: workArrangement, grade: grade, thesis: thesis, coursework: coursework, proofURL: proofURL,
            location: location
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
    /// Top and bottom; also the sides unless `sideMargins` is set.
    var margins = Margins.normal
    /// Times the font's own line height.
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
    /// `.classic` when nil.
    var template: Template?
    /// The rule under section headings and the header. nil follows the template.
    var showsDividers: Bool?
    /// Off when nil: the summary sits tight under the contact line, as part of the header.
    var showsSummaryHeading: Bool?
    /// Left and right. Same as `margins` when nil.
    var sideMargins: Margins?
    /// Points between entries in a section. 8 when nil.
    var entrySpacing: Double?
    /// Divider thickness in points. 0.5 when nil.
    var dividerWeight: Double?

    var sideMargin: Margins { sideMargins ?? margins }
    var entryGap: Double { entrySpacing ?? 8 }
    var dividerWidth: Double { dividerWeight ?? 0.5 }

    /// The layout's look. Every template is single-column and text-based (BR-001).
    enum Template: String, Codable, CaseIterable {
        /// Civa's first layout: left-aligned header, accent headings.
        case classic
        /// After the MIT CAPD sample resumes: serif, centered header, bold caps headings with a
        /// rule, organization and location first.
        case mit
        /// After the Harvard College template: centered header and centered bold caps headings.
        case harvard
        /// After Jake's Resume, common in tech hiring: small caps headings with a rule, compact.
        case tech

        var defaultFont: Font {
            switch self {
            case .classic, .tech: .helveticaNeue
            case .mit: .timesNewRoman
            case .harvard: .georgia
            }
        }

        var defaultFontSize: Double {
            switch self {
            case .classic, .tech: 10
            case .mit, .harvard: 10.5
            }
        }

        var defaultDividers: Bool { self == .mit || self == .tech }
    }

    var layout: Template { template ?? .classic }
    var dividers: Bool { showsDividers ?? layout.defaultDividers }

    /// Switches template and takes its font and size; the user can change those after.
    mutating func apply(_ template: Template) {
        self.template = template
        font = template.defaultFont
        fontSize = template.defaultFontSize
        showsDividers = nil
    }

    static let fontSizes = 9.0...12.0
    static let lineSpacings = [1.0, 1.15, 1.3]
    static let sectionSpacings = 4.0...24.0
    static let entrySpacings = 0.0...12.0
    static let dividerWeights = [0.5, 1.0, 1.5]
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
