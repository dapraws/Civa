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
        /// "Achievements, Projects, Certificates, and Skills": one line per item, each labeled.
        case mixed
        case summary
        case other
    }

    static func parse(_ text: String) -> ImportDraft {
        let lines = text.components(separatedBy: .newlines).map { closeHyphens(clean($0)) }.filter { !$0.isEmpty }
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
            case .mixed:
                let (items, leftovers) = parseMixed(section.body)
                draft.items += items
                draft.unsorted += leftovers
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

    /// "AI- powered" becomes "AI-powered": some PDFs store a hyphen with a space after it.
    /// A spaced dash between words ("Telkom University - Bandung") is left alone.
    static func closeHyphens(_ line: String) -> String {
        line.replacingOccurrences(of: #"(?<=\p{L})- (?=\p{L})"#, with: "-", options: .regularExpression)
    }

    /// The next line continues this one: no sentence end yet and it starts in lowercase, or
    /// this one breaks a word with a hyphen.
    static func continues(_ line: String, with next: String) -> Bool {
        guard let first = next.first else { return false }
        if line.hasSuffix("-") { return true }
        return !".!?:;".contains(line.last ?? ".") && first.isLowercase
    }

    /// Joins `next` onto `line`, without a space after a hyphen that broke a word.
    static func join(_ line: String, _ next: String) -> String {
        line.hasSuffix("-") ? line + next : line + " " + next
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
        guard line.count <= 60, bulletText(line) == nil, !line.contains(where: \.isNumber) else { return nil }
        let key = clean(line.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .map { $0.isLetter ? $0 : " " }
            .reduce(into: "") { $0.append($1) })
        if let heading = headings[key] { return heading }
        return headingByWords(key.split(separator: " ").map(String.init))
    }

    /// Words a section heading can be made of. A line made only of these is a heading, so
    /// "Education Level" is one and "Project Manager" isn't.
    private static let headingWords: Set<String> = [
        "experience", "experiences", "professional", "work", "relevant", "additional", "other", "employment", "history",
        "career", "internship", "internships", "organizational", "organisational", "organization", "organizations",
        "organisations", "leadership", "volunteer", "volunteering", "extracurricular", "activities", "education",
        "educational", "level", "academic", "background", "projects", "project", "personal", "selected", "portfolio",
        "achievements", "achievement", "awards", "award", "honors", "honours", "accomplishments", "certifications",
        "certification", "certificates", "certificate", "licenses", "licences", "courses", "training", "skills", "skill",
        "technical", "tools", "technologies", "and", "summary", "profile", "about", "me", "languages", "interests",
        "pengalaman", "kerja", "profesional", "organisasi", "kepanitiaan", "pendidikan", "riwayat", "proyek", "projek",
        "prestasi", "penghargaan", "sertifikat", "sertifikasi", "pelatihan", "keahlian", "keterampilan", "kemampuan",
        "dan", "lainnya", "tambahan",
    ]

    /// Which category each heading word points to. Organizational words win over "experience",
    /// so "Additional Experience" and "Leadership Experience" are organizational.
    private static let headingKeywords: [(category: ImportCategory, words: Set<String>)] = [
        (.organizational, ["organizational", "organisational", "organization", "organizations", "organisations", "leadership",
                           "volunteer", "volunteering", "extracurricular", "activities", "additional", "organisasi",
                           "kepanitiaan", "tambahan"]),
        (.education, ["education", "educational", "academic", "pendidikan"]),
        (.projects, ["projects", "project", "portfolio", "proyek", "projek"]),
        (.achievements, ["achievements", "achievement", "awards", "award", "honors", "honours", "accomplishments",
                         "prestasi", "penghargaan"]),
        (.certifications, ["certifications", "certification", "certificates", "certificate", "licenses", "licences",
                           "courses", "training", "sertifikat", "sertifikasi", "pelatihan"]),
        (.skills, ["skills", "skill", "tools", "technologies", "keahlian", "keterampilan", "kemampuan"]),
        (.experience, ["experience", "experiences", "work", "employment", "internship", "internships", "career", "pengalaman", "kerja"]),
    ]

    private static func headingByWords(_ words: [String]) -> Heading? {
        guard !words.isEmpty, words.count <= 7, words.allSatisfy(headingWords.contains) else { return nil }
        let found = headingKeywords.filter { !$0.words.isDisjoint(with: words) }.map(\.category)
        // Several item kinds named in one heading, beyond organizational's own "experience".
        let kinds = Set(found).subtracting(found.contains(.organizational) ? [.experience] : [])
        if kinds.count > 1 { return .mixed }
        if let category = found.first { return .category(category) }
        if !Set(words).isDisjoint(with: ["summary", "profile", "about"]) { return .summary }
        return .other
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
            // A wrapped line continues the bullet above it.
            if bulletText(line) == nil, let last = blocks.last?.bullets.last, continues(last, with: line) {
                blocks[blocks.count - 1].bullets[blocks[blocks.count - 1].bullets.count - 1] = join(last, line)
                continue
            }
            if let bullet = bulletText(line) {
                if blocks.isEmpty { blocks.append(Block()) }
                // "- Remote" wrapped off the dates line is the location, not a bullet.
                let block = blocks[blocks.count - 1]
                if block.bullets.isEmpty, block.dates != nil, block.texts.count == 1, isLocation(bullet) {
                    blocks[blocks.count - 1].texts[0] += " - " + bullet
                    continue
                }
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
        // MIT-style entries: "Organization - Location" with the dates, the role on the next line.
        if block.dates != nil, texts.count >= 2, let (organization, location) = splitLocation(texts[0]) {
            item.location = location
            texts = [texts[1], organization] + texts.dropFirst(2)
        } else if texts.count == 1 {
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

    /// "Acme Labs - Bali, Indonesia" as the organization and its location, split at the last
    /// dash or bar, when what follows reads as a place.
    static func splitLocation(_ text: String) -> (String, String)? {
        for separator in [" - ", " – ", " — ", " | "] {
            guard let range = text.range(of: separator, options: .backwards) else { continue }
            let place = clean(String(text[range.upperBound...]))
            let organization = clean(String(text[..<range.lowerBound]))
            if !organization.isEmpty, isLocation(place) { return (organization, place) }
        }
        return nil
    }

    /// "Bandung, Indonesia", "Remote", "Jakarta": short, and a city with its region or a work mode.
    static func isLocation(_ text: String) -> Bool {
        let lower = text.lowercased()
        if ["remote", "hybrid", "on-site", "onsite", "online", "work from home", "wfh"].contains(lower) { return true }
        let words = text.split(separator: " ")
        return text.contains(",") && words.count <= 5 && words.allSatisfy { $0.first?.isUppercase == true }
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

    // MARK: - Combined sections

    /// One labeled line per item: "Achievements (2025): Best Pitching | Hack Batch",
    /// "Certificate (2024): Cloud Fundamentals | Example Cloud", "Hard Skills: Python, Swift".
    /// A line without a label continues the one above.
    private static func parseMixed(_ lines: [String]) -> (items: [ImportItem], leftovers: [String]) {
        let label = /^([^:()]{1,40}?)\s*(?:\((\d{4})\))?\s*:\s*(.*)$/
        var joined: [String] = []
        for line in lines {
            if let last = joined.last, line.firstMatch(of: label) == nil {
                joined[joined.count - 1] = last.hasSuffix("|") || last.hasSuffix("-") ? join(last, line) : last + ", " + line
            } else {
                joined.append(line)
            }
        }
        var items: [ImportItem] = []
        var skillLines: [String] = []
        var leftovers: [String] = []
        for line in joined {
            guard let match = line.firstMatch(of: label) else {
                leftovers.append(line)
                continue
            }
            let name = clean(String(match.output.1))
            let words = Set(name.lowercased().split(separator: " ").map(String.init))
            let category = headingKeywords.first { !$0.words.isDisjoint(with: words) }?.category ?? .projects
            if category == .skills {
                skillLines.append("\(name): \(match.output.3)")
                continue
            }
            let parts = String(match.output.3).components(separatedBy: " | ").map(clean)
            var item = ImportItem(category: category == .experience || category == .organizational ? .projects : category)
            item.title = parts.first ?? ""
            item.subtitle = parts.dropFirst().joined(separator: " · ")
            item.start = match.output.2.flatMap { Int($0) }.map { YearMonth(year: $0) }
            items.append(item)
        }
        let (skills, skillLeftovers) = parseSkills(skillLines)
        return (items + skills, leftovers + skillLeftovers)
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
