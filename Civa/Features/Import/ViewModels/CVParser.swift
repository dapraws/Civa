//
//  CVParser.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Sorts a CV's plain text into Career Profile items with simple rules, no AI (FR-020).
/// Works for English and Indonesian headings. Anything it can't place goes to `unsorted`.
// ponytail: line-based heuristics suit single-column CVs; two-column layouts land mostly in
// unsorted. The review step absorbs the misses; AI-assisted extraction is a Phase 4 option.
nonisolated enum CVParser {
    private enum Heading {
        case category(ImportCategory)
        case summary
        case other
    }

    static func parse(_ text: String) -> ImportDraft {
        let lines = text.components(separatedBy: .newlines).map(clean).filter { !$0.isEmpty }
        var header: [String] = []
        var sections: [(heading: Heading, title: String, body: [String])] = []
        for line in lines {
            if let heading = heading(for: line) {
                sections.append((heading, line, []))
            } else if sections.isEmpty {
                header.append(line)
            } else {
                sections[sections.count - 1].body.append(line)
            }
        }

        var draft = ImportDraft()
        parseHeader(header, into: &draft)
        for section in sections {
            switch section.heading {
            case .category(.skills):
                let (skills, leftovers) = parseSkills(section.body)
                draft.items += skills
                draft.unsorted += leftovers
            case .category(let category):
                draft.items += parseEntries(section.body, category: category)
            case .summary, .other:
                if !section.body.isEmpty { draft.unsorted += [section.title] + section.body }
            }
        }
        return draft
    }

    // MARK: - Lines

    static func clean(_ line: String) -> String {
        line.replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let bulletMarks: Set<Character> = ["•", "·", "▪", "●", "◦", "‣", "-", "–", "*", "○", "■", "♦"]

    /// The text after a bullet mark, or nil when the line isn't a bullet.
    static func bulletText(_ line: String) -> String? {
        guard let first = line.first, bulletMarks.contains(first) else { return nil }
        let text = clean(String(line.dropFirst()))
        return text.isEmpty ? nil : text
    }

    /// A full sentence rather than a title: long, or ending in a period.
    private static func isSentence(_ line: String) -> Bool {
        line.count > 70 || line.hasSuffix(".")
    }

    // MARK: - Headings

    private static let headings: [String: Heading] = {
        var map: [String: Heading] = [:]
        func add(_ heading: Heading, _ names: [String]) { names.forEach { map[$0] = heading } }
        add(.category(.experience), [
            "experience", "work experience", "professional experience", "employment", "employment history",
            "work history", "career history", "relevant experience", "internship", "internships", "internship experience",
            "pengalaman", "pengalaman kerja", "pengalaman profesional", "riwayat pekerjaan", "pengalaman magang",
        ])
        add(.category(.organizational), [
            "organizational experience", "organisational experience", "organization experience", "organizations",
            "organisations", "leadership", "leadership experience", "volunteer", "volunteering", "volunteer experience",
            "extracurricular", "extracurricular activities", "activities",
            "pengalaman organisasi", "organisasi", "kepanitiaan", "pengalaman kepanitiaan", "kegiatan",
        ])
        add(.category(.education), [
            "education", "academic background", "educational background", "academic history",
            "pendidikan", "riwayat pendidikan", "latar belakang pendidikan",
        ])
        add(.category(.projects), [
            "projects", "project", "personal projects", "selected projects", "portfolio", "project experience",
            "proyek", "projek", "portofolio",
        ])
        add(.category(.achievements), [
            "achievements", "awards", "honors", "honours", "awards and honors", "awards and achievements", "accomplishments",
            "prestasi", "penghargaan", "pencapaian",
        ])
        add(.category(.certifications), [
            "certifications", "certificates", "certification", "licenses and certifications", "licences and certifications",
            "courses", "training", "sertifikasi", "sertifikat", "pelatihan",
        ])
        add(.category(.skills), [
            "skills", "technical skills", "skills and tools", "core skills", "key skills", "hard skills", "soft skills",
            "skills and expertise", "tools", "technologies", "tech stack",
            "keahlian", "kemampuan", "keterampilan", "keahlian teknis",
        ])
        add(.summary, [
            "summary", "profile", "about", "about me", "professional summary", "objective", "career objective",
            "ringkasan", "tentang saya", "profil", "profil singkat",
        ])
        add(.other, [
            "languages", "language", "interests", "hobbies", "references", "publications", "contact",
            "bahasa", "minat", "hobi", "referensi", "publikasi", "kontak",
        ])
        return map
    }()

    private static func heading(for line: String) -> Heading? {
        guard line.count <= 45, bulletText(line) == nil else { return nil }
        let key = line.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .filter { $0.isLetter || $0 == " " }
        return headings[clean(key)]
    }

    // MARK: - Header

    private static func parseHeader(_ lines: [String], into draft: inout ImportDraft) {
        for line in lines {
            let tokens = line.split(whereSeparator: { "|·•\t".contains($0) }).map { clean(String($0)) }.filter { !$0.isEmpty }
            var leftovers: [String] = []
            var hasContact = false
            for token in tokens {
                if let email = email(in: token) {
                    if draft.personal.email.isEmpty { draft.personal.email = email }
                    hasContact = true
                } else if isLink(token) {
                    draft.personal.links.append(ProfileLink(label: linkLabel(token), url: token))
                    hasContact = true
                } else if isPhone(token) {
                    if draft.personal.phone.isEmpty { draft.personal.phone = token }
                    hasContact = true
                } else {
                    leftovers.append(token)
                }
            }
            for token in leftovers {
                if !hasContact, draft.personal.fullName.isEmpty, token.split(separator: " ").count <= 5 {
                    draft.personal.fullName = token
                } else if !hasContact, draft.personal.headline.isEmpty, !isSentence(token) {
                    draft.personal.headline = token
                } else if draft.personal.location.isEmpty, token.split(separator: " ").count <= 4 {
                    draft.personal.location = token
                } else {
                    draft.unsorted.append(token)
                }
            }
        }
    }

    static func email(in text: String) -> String? {
        let pattern = /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/
        return text.firstMatch(of: pattern).map { String($0.output) }
    }

    static func isPhone(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber).count
        return digits >= 8 && text.allSatisfy { $0.isNumber || "+()-. ".contains($0) }
    }

    static func isLink(_ text: String) -> Bool {
        let lower = text.lowercased()
        guard !lower.contains(" ") else { return false }
        return lower.hasPrefix("http") || lower.hasPrefix("www.") || lower.contains("linkedin.com") || lower.contains("github.com")
            || lower.firstMatch(of: /^[a-z0-9.\-]+\.(com|io|dev|me|id|net|org|app|co)(\/\S*)?$/) != nil
    }

    private static func linkLabel(_ url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("linkedin") { return "LinkedIn" }
        if lower.contains("github") { return "GitHub" }
        return String(localized: "Website")
    }

    // MARK: - Dates

    struct DateLine: Equatable {
        var start: YearMonth?
        var end: YearMonth?
        var isCurrent = false
        /// The line with the dates taken out.
        var rest: String
    }

    private static let months: [(prefixes: [String], month: Int)] = [
        (["jan"], 1), (["feb", "peb"], 2), (["mar"], 3), (["apr"], 4), (["may", "mei"], 5), (["jun"], 6),
        (["jul"], 7), (["aug", "agu", "agt", "ags"], 8), (["sep"], 9), (["oct", "okt"], 10), (["nov", "nop"], 11), (["dec", "des"], 12),
    ]

    private static let monthWords =
        "jan(?:uary|uari)?|feb(?:ruary|ruari)?|peb(?:ruari)?|mar(?:ch|et)?|apr(?:il)?|may|mei|jun(?:e|i)?|jul(?:y|i)?"
        + "|aug(?:ust)?|agu(?:stus)?|agt|ags|sep(?:t|tember)?|oct(?:ober)?|okt(?:ober)?|nov(?:ember)?|nop(?:ember)?|dec(?:ember)?|des(?:ember)?"
    private static let date = "(?:(?:\(monthWords))\\.?\\s+(?:19|20)\\d{2}|\\d{1,2}/(?:19|20)\\d{2}|(?:19|20)\\d{2})"
    private static let present = "(?:present|current|now|today|ongoing|sekarang|saat ini|kini)"

    /// Finds a date range ("Mar 2024 – Present", "2019 - 2023") or a single date in a line.
    static func dateLine(_ line: String) -> DateLine? {
        let range = "(\(date))\\s*(?:-|–|—|to|until|sampai|hingga|s/d|s\\.d\\.)\\s*(\(date)|\(present))"
        if let match = firstMatch(range, in: line) {
            let startText = match.groups[0]
            let endText = match.groups[1]
            let isCurrent = firstMatch("^\(present)$", in: endText) != nil
            return DateLine(
                start: yearMonth(startText),
                end: isCurrent ? nil : yearMonth(endText),
                isCurrent: isCurrent,
                rest: trimSeparators(line.replacingCharacters(in: match.range, with: " "))
            )
        }
        if let match = firstMatch("(\(date))", in: line) {
            return DateLine(start: yearMonth(match.groups[0]), rest: trimSeparators(line.replacingCharacters(in: match.range, with: " ")))
        }
        return nil
    }

    static func yearMonth(_ text: String) -> YearMonth? {
        let lower = text.lowercased()
        guard let yearMatch = lower.firstMatch(of: /(19|20)\d{2}/), let year = Int(yearMatch.output.0) else { return nil }
        if let slash = lower.firstMatch(of: /^(\d{1,2})\//), let month = Int(slash.output.1), (1...12).contains(month) {
            return YearMonth(year: year, month: month)
        }
        let month = months.first { entry in entry.prefixes.contains { lower.hasPrefix($0) } }?.month
        return YearMonth(year: year, month: month)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> (range: Range<String.Index>, groups: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text)
        else { return nil }
        let groups = (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
        return (range, groups)
    }

    private static func trimSeparators(_ text: String) -> String {
        clean(text).trimmingCharacters(in: CharacterSet(charactersIn: " |,·•–—-()[]:"))
    }

    // MARK: - Entries

    private struct Block {
        var texts: [String] = []
        var bullets: [String] = []
        var dates: DateLine?
    }

    private static func parseEntries(_ lines: [String], category: ImportCategory) -> [ImportItem] {
        var blocks: [Block] = []
        for line in lines {
            if let bullet = bulletText(line) {
                if blocks.isEmpty { blocks.append(Block()) }
                blocks[blocks.count - 1].bullets.append(bullet)
            } else if let dates = dateLine(line), !isSentence(line) {
                if blocks.isEmpty || blocks[blocks.count - 1].dates != nil || !blocks[blocks.count - 1].bullets.isEmpty {
                    blocks.append(Block())
                }
                blocks[blocks.count - 1].dates = dates
                if !dates.rest.isEmpty { blocks[blocks.count - 1].texts.append(dates.rest) }
            } else if isSentence(line) {
                if blocks.isEmpty { blocks.append(Block()) }
                blocks[blocks.count - 1].bullets.append(line)
            } else {
                let last = blocks.last
                if last == nil || !(last!.bullets.isEmpty) || (last!.dates != nil && last!.texts.count >= 2) {
                    blocks.append(Block())
                }
                blocks[blocks.count - 1].texts.append(line)
            }
        }
        return blocks.map { item(from: $0, category: category) }
    }

    private static let institutionWords = [
        "university", "universitas", "institut", "institute", "college", "school", "sekolah", "politeknik",
        "polytechnic", "academy", "akademi", "sma ", "smk ", "sman", "smkn", "stmik", "stie", "binus", "its", "itb", "ugm",
    ]

    private static func item(from block: Block, category: ImportCategory) -> ImportItem {
        var item = ImportItem(category: category)
        item.start = block.dates?.start
        item.end = block.dates?.end
        item.isCurrent = block.dates?.isCurrent ?? false
        item.bullets = block.bullets

        var texts = block.texts
        if texts.count == 1 {
            texts = splitTitle(texts[0])
        }
        item.title = texts.first ?? ""
        item.subtitle = texts.count > 1 ? texts[1] : ""
        for extra in texts.dropFirst(2) {
            if item.location.isEmpty, extra.split(separator: " ").count <= 4 {
                item.location = extra
            } else {
                item.bullets.insert(extra, at: 0)
            }
        }
        // "Tokopedia · Jakarta" carries the location after the organization.
        let parts = item.subtitle.split(whereSeparator: { "·|•".contains($0) }).map { clean(String($0)) }
        if parts.count == 2, item.location.isEmpty {
            item.subtitle = parts[0]
            item.location = parts[1]
        }
        if category == .education, isInstitution(item.title), !isInstitution(item.subtitle) {
            swap(&item.title, &item.subtitle)
        }
        if category == .experience {
            item.employmentType = takeEmploymentType(from: &item.title)
                ?? takeEmploymentType(from: &item.subtitle)
                ?? takeEmploymentType(from: &item.location)
        }
        return item
    }

    /// Removes an employment type named as its own part of `text`: "Tokopedia · Full-time",
    /// "iOS Engineer (Internship)", or just "Magang".
    static func takeEmploymentType(from text: inout String) -> EmploymentType? {
        let parts = text.split(whereSeparator: { "·|•()[]".contains($0) }).map { clean(String($0)) }
        guard let index = parts.firstIndex(where: { EmploymentType.find(in: $0) != nil }) else { return nil }
        let type = EmploymentType.find(in: parts[index])
        var rest = parts
        rest.remove(at: index)
        text = rest.filter { !$0.isEmpty }.joined(separator: " · ")
        return type
    }

    /// "iOS Engineer — Tokopedia", "iOS Engineer at Tokopedia", "Tokopedia | iOS Engineer".
    private static func splitTitle(_ text: String) -> [String] {
        for separator in [" — ", " – ", " - ", " | ", " at ", " di ", " @ ", ", "] {
            let parts = text.components(separatedBy: separator)
            if parts.count >= 2 {
                return [clean(parts[0]), clean(parts.dropFirst().joined(separator: separator))]
            }
        }
        return [text]
    }

    private static func isInstitution(_ text: String) -> Bool {
        let lower = text.lowercased() + " "
        return institutionWords.contains { lower.contains($0) }
    }

    // MARK: - Skills

    /// "Languages: Swift, Kotlin" gives two skills in Languages. Long lines that aren't lists stay unsorted.
    private static func parseSkills(_ lines: [String]) -> (skills: [ImportItem], leftovers: [String]) {
        var skills: [ImportItem] = []
        var leftovers: [String] = []
        var seen: Set<String> = []
        for line in lines {
            let text = bulletText(line) ?? line
            var category = ""
            var list = text
            if let colon = text.firstIndex(of: ":"), text[..<colon].split(separator: " ").count <= 4 {
                category = clean(String(text[..<colon]))
                list = String(text[text.index(after: colon)...])
            }
            let names = list.split(whereSeparator: { ",;•|·".contains($0) }).map { clean(String($0)) }.filter { !$0.isEmpty }
            if names.count == 1, isSentence(names[0]) {
                leftovers.append(line)
                continue
            }
            for name in names where name.count <= 40 && seen.insert(name.lowercased()).inserted {
                skills.append(ImportItem(category: .skills, title: name, subtitle: category))
            }
        }
        return (skills, leftovers)
    }
}
