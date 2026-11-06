//
//  LinkedInPDF.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import PDFKit

/// Reads the PDF LinkedIn makes with "Save to PDF" (FR-021). Its layout is fixed: a sidebar
/// (Contact, Top Skills, Languages, Certifications, Honors-Awards) beside a main column, and each
/// line's role shows in its font size, so this reads by size and position rather than guessing.
// ponytail: tied to LinkedIn's current sizes (name 26, headings 15.75/13, company 12, role 11.5,
// body 10.5). If LinkedIn changes them, detection fails and the import falls back to plain CV rules.
nonisolated enum LinkedInPDF {
    struct Line: Equatable {
        var text: String
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var page: Int
    }

    /// Every text line with its position and font size, page by page, top to bottom.
    static func lines(of document: PDFDocument) -> [Line] {
        (0..<document.pageCount).flatMap { index -> [Line] in
            guard let page = document.page(at: index) else { return [] }
            return (page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine() ?? []).compactMap { selection in
                guard let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                let bounds = selection.bounds(for: page)
                let font = selection.attributedString.flatMap { string in
                    string.length > 0 ? string.attribute(.font, at: 0, effectiveRange: nil) as? NSFont : nil
                }
                return Line(text: text, x: bounds.minX, y: bounds.minY, size: font?.pointSize ?? 0, page: index)
            }
        }
    }

    /// LinkedIn's PDF has "Page 1 of N" footers and a sidebar headed "Contact" or "Top Skills".
    static func isLinkedIn(_ lines: [Line]) -> Bool {
        lines.contains { $0.text.firstMatch(of: /^Page \d+ of \d+$/) != nil }
            && lines.contains { isSidebar($0) && ["Contact", "Top Skills"].contains($0.text) }
    }

    private static func isSidebar(_ line: Line) -> Bool { line.x < 150 }
    private static func isFooter(_ line: Line) -> Bool { line.size < 9.5 || line.text.firstMatch(of: /^Page \d+ of \d+$/) != nil }
    private static func near(_ size: CGFloat, _ target: CGFloat) -> Bool { abs(size - target) < 0.2 }

    /// The text as two readable columns, main first, for the review window.
    static func text(of lines: [Line]) -> String {
        let main = lines.filter { !isSidebar($0) && !isFooter($0) }.map(\.text)
        let sidebar = lines.filter { isSidebar($0) && !isFooter($0) }.map(\.text)
        return (main + [""] + sidebar).joined(separator: "\n")
    }

    static func draft(from lines: [Line]) -> ImportDraft {
        var draft = ImportDraft()
        readMain(lines.filter { !isSidebar($0) && !isFooter($0) }, into: &draft)
        readSidebar(lines.filter { isSidebar($0) && !isFooter($0) }, into: &draft)
        return draft
    }

    // MARK: - Main column

    private static func readMain(_ lines: [Line], into draft: inout ImportDraft) {
        var section = ""
        var intro: [String] = []
        var summary = Paragraphs()
        var company = ""
        var item: ImportItem?
        var details = Paragraphs()
        var afterDates = false
        var previous: Line?

        func finish() {
            guard var finished = item else { return }
            if finished.category == .education {
                finished = education(finished, details.lines.joined(separator: " "))
            } else {
                finished.bullets = details.lines
            }
            draft.items.append(finished)
            item = nil
            details = Paragraphs()
        }

        for line in lines {
            defer { previous = line }
            if line.size >= 20 {
                draft.personal.fullName = line.text
                continue
            }
            if line.size >= 15 {
                finish()
                section = line.text.lowercased()
                continue
            }
            switch section {
            case "":
                intro.append(line.text)
            case "summary":
                summary.add(line, after: previous)
            case "experience":
                if near(line.size, 12) {
                    finish()
                    company = line.text
                } else if near(line.size, 11.5) {
                    finish()
                    item = ImportItem(category: .experience, title: line.text, subtitle: company)
                    afterDates = false
                } else if var current = item, current.start == nil, !current.isCurrent, let dates = CVParser.dateLine(line.text) {
                    current.start = dates.start
                    current.end = dates.end
                    current.isCurrent = dates.isCurrent
                    item = current
                    afterDates = true
                } else if item != nil, afterDates, let previous, previous.page == line.page, previous.y - line.y < 18 {
                    item?.location = line.text  // sits right under the dates
                    afterDates = false
                } else if item != nil {
                    afterDates = false
                    details.add(line, after: previous)
                }
                // A body line between a company and its first role is the total time there; skip it.
            case "education":
                if near(line.size, 12) {
                    finish()
                    item = ImportItem(category: .education, subtitle: line.text)
                } else if item != nil {
                    details.add(line, after: previous, joinAll: true)
                }
            default:
                draft.unsorted.append(line.text)
            }
        }
        finish()

        // Under the name: the headline (which may wrap), then the location on its own line.
        if let location = intro.last, intro.count > 1 {
            draft.personal.headline = join(intro.dropLast())
            draft.personal.location = location
        } else {
            draft.personal.headline = intro.first ?? ""
        }
        draft.unsorted.insert(contentsOf: summary.lines, at: 0)
    }

    /// "Bachelor's degree, Informatics · (2021 - July 2024)" gives the degree and dates.
    private static func education(_ item: ImportItem, _ text: String) -> ImportItem {
        var item = item
        let parts = text.components(separatedBy: " · ")
        item.title = CVParser.clean(parts[0])
        if parts.count > 1, let dates = CVParser.dateLine(parts.dropFirst().joined(separator: " ")) {
            item.start = dates.start
            item.end = dates.end
            item.isCurrent = dates.isCurrent
        }
        return item
    }

    // MARK: - Sidebar

    private static func readSidebar(_ lines: [Line], into draft: inout ImportDraft) {
        var sections: [(heading: String, items: [String], lines: [String])] = []
        var previous: Line?
        for line in lines {
            defer { previous = line }
            if near(line.size, 13) {
                sections.append((line.text, [], []))
                continue
            }
            guard !sections.isEmpty else { continue }
            sections[sections.count - 1].lines.append(line.text)
            let continues = previous.map { $0.page == line.page && $0.y - line.y < 15 && !near($0.size, 13) } ?? false
            if continues, var last = sections[sections.count - 1].items.popLast() {
                last = last.hasSuffix("-") ? last + line.text : last + " " + line.text
                sections[sections.count - 1].items.append(last)
            } else {
                sections[sections.count - 1].items.append(line.text)
            }
        }

        for section in sections {
            switch section.heading.lowercased() {
            case "contact":
                readContact(section.lines, into: &draft)
            case "top skills", "skills":
                draft.items += section.items.map { ImportItem(category: .skills, title: $0) }
            case "languages":
                draft.items += section.items.map {
                    ImportItem(category: .skills, title: withoutParentheses($0), subtitle: String(localized: "Languages"))
                }
            case "certifications", "licenses & certifications":
                draft.items += section.items.map { ImportItem(category: .certifications, title: $0) }
            case "honors-awards", "honors & awards":
                draft.items += section.items.map(award)
            default:
                draft.unsorted += [section.heading] + section.items
            }
        }
    }

    /// Contact lines are grouped closer than other items, so they're read as written: a link that
    /// wraps at a hyphen is rejoined, and a "(LinkedIn)" line labels the link above it.
    private static func readContact(_ lines: [String], into draft: inout ImportDraft) {
        var entries: [(text: String, label: String)] = []
        for line in lines {
            if let label = line.firstMatch(of: /^\(([^()]+)\)$/), !entries.isEmpty {
                entries[entries.count - 1].label = String(label.output.1)
            } else if let last = entries.last, last.text.hasSuffix("-"), last.label.isEmpty {
                let joined = splitLabel(last.text + line)
                entries[entries.count - 1] = joined
            } else {
                entries.append(splitLabel(line))
            }
        }
        for entry in entries {
            if let email = CVParser.email(in: entry.text) {
                if draft.personal.email.isEmpty { draft.personal.email = email }
            } else if CVParser.isPhone(entry.text) {
                if draft.personal.phone.isEmpty { draft.personal.phone = entry.text }
            } else if CVParser.isLink(entry.text) {
                let label = switch entry.label.lowercased() {
                case "linkedin": "LinkedIn"
                case "": entry.text.contains("github") ? "GitHub" : String(localized: "Website")
                case "personal": String(localized: "Website")
                default: entry.label
                }
                draft.personal.links.append(ProfileLink(label: label, url: entry.text))
            } else {
                draft.unsorted.append(entry.text)  // usually a street address
            }
        }
    }

    /// "ada4career.com (Portfolio)" → the text and its label; "081337130753 (Mobile)" likewise.
    private static func splitLabel(_ text: String) -> (text: String, label: String) {
        guard let match = text.firstMatch(of: /^(.+?)\s*\(([^()]+)\)$/) else { return (text, "") }
        return (String(match.output.1), String(match.output.2))
    }

    /// "Finalist (5th Place) | 2023 Lomba Inovasi Digital" → title, year, and what it was for.
    private static func award(_ text: String) -> ImportItem {
        let parts = text.split(separator: "|", maxSplits: 1).map { CVParser.clean(String($0)) }
        var item = ImportItem(category: .achievements, title: parts[0])
        if parts.count > 1 {
            var rest = parts[1]
            if let year = rest.firstMatch(of: /^((?:19|20)\d{2})\s*/) {
                item.start = YearMonth(year: Int(year.output.1) ?? 0)
                rest = String(rest[year.range.upperBound...])
            }
            item.subtitle = rest
        } else if let dash = text.range(of: " - ") {
            item.title = String(text[..<dash.lowerBound])
            item.subtitle = String(text[dash.upperBound...])
        }
        return item
    }

    private static func withoutParentheses(_ text: String) -> String {
        CVParser.clean(text.replacing(/\s*\([^)]*\)/, with: ""))
    }

    /// Wrapped lines joined back: a line ending in a hyphen continues without a space ("end-to-" + "end").
    private static func join(_ lines: some Sequence<String>) -> String {
        lines.reduce("") { joined, line in
            joined.isEmpty ? line : joined.hasSuffix("-") ? joined + line : joined + " " + line
        }
    }

    /// Body text rebuilt into paragraphs and list items from line spacing.
    private struct Paragraphs {
        private(set) var lines: [String] = []

        mutating func add(_ line: Line, after previous: Line?, joinAll: Bool = false) {
            let text = line.text.replacingOccurrences(of: "&nbsp;", with: " ")
            let startsItem = text.firstMatch(of: /^(\d+[.)]|[-•*–])\s/) != nil
            // Lines in a paragraph are 18 pt apart; a blank line or a page break makes it larger.
            let sameParagraph = previous.map { $0.page != line.page || $0.y - line.y < 25 } ?? false
            if let last = lines.last, joinAll || (sameParagraph && !startsItem) {
                lines[lines.count - 1] = LinkedInPDF.join([last, text])
            } else {
                // "1. Monitoring…" and "- 20,000 alerts" become plain list items.
                let item = text.replacing(/^\d+[.)]\s+/, with: "")
                lines.append(CVParser.bulletText(item) ?? item)
            }
        }
    }
}
