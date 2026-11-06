//
//  ResumeDocument.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// A resume's own content and formatting. It's a copy, not a reference: editing a resume never
/// changes the Career Profile or another resume, and the reverse holds too (FR-034, FR-041).
nonisolated struct ResumeDocument: Codable, Hashable {
    var header = ResumeHeader()
    /// Shown under the header without a heading.
    var summary = ""
    /// In display order (FR-036 section order).
    var sections: [ResumeSection] = []
    var format = ResumeFormat()

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
    /// Each kind has a fixed, standard heading so resumes stay ATS-friendly (BR-001).
    enum Kind: String, Codable, CaseIterable {
        case experience, organizational, education, projects, achievements, certifications, skills

        var heading: String {
            switch self {
            case .experience: String(localized: "Experience")
            case .organizational: String(localized: "Organizational Experience")
            case .education: String(localized: "Education")
            case .projects: String(localized: "Projects")
            case .achievements: String(localized: "Achievements")
            case .certifications: String(localized: "Certifications")
            case .skills: String(localized: "Skills")
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var entries: [ResumeEntry] = []
}

/// One item in a section. For skills, `title` is the category and `subtitle` the skills.
nonisolated struct ResumeEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    /// The profile record this came from, for Suggested Changes later (FR-042).
    var sourceID: UUID?
    var title = ""
    var subtitle = ""
    var dates = ""
    var bullets: [String] = []
}

/// Customization limited to what keeps the layout single-column and ATS-safe (FR-036).
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

    static let fontSizes = 9.0...12.0
    static let lineSpacings = [1.0, 1.15, 1.3]
    static let sectionSpacings = 6.0...18.0
}

nonisolated extension Array where Element: Identifiable {
    /// Moves the element with `id` one place up (-1) or down (+1). Does nothing at the ends.
    mutating func move(id: Element.ID, by offset: Int) {
        guard let index = firstIndex(where: { $0.id == id }), indices.contains(index + offset) else { return }
        swapAt(index, index + offset)
    }
}
