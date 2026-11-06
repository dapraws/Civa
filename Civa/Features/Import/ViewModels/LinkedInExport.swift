//
//  LinkedInExport.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Maps LinkedIn's data export ("Get a copy of your data") into an import draft (FR-021).
/// The export is a ZIP of CSV files with named columns, so no guessing is needed. Only the
/// profile files below are read; connections, messages, and the rest are never opened.
nonisolated enum LinkedInExport {
    static let fileNames: Set<String> = [
        "profile.csv", "email addresses.csv", "phonenumbers.csv", "positions.csv", "volunteering.csv",
        "education.csv", "projects.csv", "honors.csv", "certifications.csv", "skills.csv", "languages.csv",
    ]

    static func isProfileFile(_ path: String) -> Bool {
        fileNames.contains((path as NSString).lastPathComponent.lowercased())
    }

    enum Failure: LocalizedError {
        case notAnExport

        var errorDescription: String? {
            String(localized: "This doesn't look like a LinkedIn data export. Choose the ZIP LinkedIn emailed you, or its unzipped folder.")
        }
    }

    /// Reads the profile files from a ZIP or an unzipped folder, keyed by lowercased file name.
    static func files(at url: URL) throws -> [String: String] {
        var files: [String: String] = [:]
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let paths = FileManager.default.enumerator(atPath: url.path)?.allObjects as? [String] ?? []
            for path in paths where isProfileFile(path) {
                files[(path as NSString).lastPathComponent.lowercased()] =
                    try? String(contentsOf: url.appending(path: path), encoding: .utf8)
            }
        } else {
            let data = try Data(contentsOf: url)
            for (path, content) in try ZipReader.files(in: data, where: isProfileFile) {
                files[(path as NSString).lastPathComponent.lowercased()] = String(decoding: content, as: UTF8.self)
            }
        }
        guard !files.isEmpty else { throw Failure.notAnExport }
        return files
    }

    static func draft(from files: [String: String]) -> ImportDraft {
        func records(_ name: String) -> [[String: String]] { files[name].map(CSVReader.records) ?? [] }
        var draft = ImportDraft()

        if let profile = records("profile.csv").first {
            draft.personal.fullName = [profile["First Name"], profile["Last Name"]]
                .compactMap { $0 }.filter { !$0.isBlank }.joined(separator: " ")
            draft.personal.headline = profile["Headline"] ?? ""
            draft.personal.location = profile["Geo Location"] ?? ""
            draft.personal.links = websites(profile["Websites"] ?? "")
            if let summary = profile["Summary"], !summary.isBlank { draft.unsorted.append(summary) }
        }
        let emails = records("email addresses.csv")
        draft.personal.email = (emails.first { $0["Primary"] == "Yes" } ?? emails.first)?["Email Address"] ?? ""
        draft.personal.phone = records("phonenumbers.csv").first?["Number"] ?? ""

        draft.items += records("positions.csv").map { row in
            dated(ImportItem(
                category: .experience, title: row["Title"] ?? "", subtitle: row["Company Name"] ?? "",
                location: row["Location"] ?? "", bullets: lines(row["Description"])
            ), from: row["Started On"], to: row["Finished On"])
        }
        draft.items += records("volunteering.csv").map { row in
            dated(ImportItem(
                category: .organizational, title: row["Role"] ?? "", subtitle: row["Company Name"] ?? "",
                bullets: lines(row["Description"])
            ), from: row["Started On"], to: row["Finished On"])
        }
        draft.items += records("education.csv").map { row in
            dated(ImportItem(
                category: .education, title: row["Degree Name"] ?? "", subtitle: row["School Name"] ?? "",
                bullets: lines(row["Notes"]) + lines(row["Activities"])
            ), from: row["Start Date"], to: row["End Date"], ongoing: false)
        }
        draft.items += records("projects.csv").map { row in
            dated(ImportItem(category: .projects, title: row["Title"] ?? "", bullets: lines(row["Description"])),
                  from: row["Started On"], to: row["Finished On"])
        }
        draft.items += records("honors.csv").map { row in
            ImportItem(
                category: .achievements, title: row["Title"] ?? "", subtitle: row["Issuer"] ?? "",
                start: row["Issued On"].flatMap(CVParser.yearMonth), bullets: lines(row["Description"])
            )
        }
        draft.items += records("certifications.csv").map { row in
            ImportItem(
                category: .certifications, title: row["Name"] ?? "", subtitle: row["Authority"] ?? "",
                start: row["Started On"].flatMap(CVParser.yearMonth)
            )
        }
        draft.items += records("skills.csv").compactMap { row in
            row["Name"].flatMap { $0.isBlank ? nil : ImportItem(category: .skills, title: $0) }
        }
        draft.items += records("languages.csv").compactMap { row in
            row["Name"].flatMap { $0.isBlank ? nil : ImportItem(category: .skills, title: $0, subtitle: String(localized: "Languages")) }
        }
        draft.items.removeAll { $0.title.isBlank && $0.subtitle.isBlank }
        return draft
    }

    /// "Started On" and "Finished On" read like "Mar 2024" or "2024". No end date means it's ongoing,
    /// except for education, where LinkedIn often leaves it out.
    private static func dated(_ item: ImportItem, from start: String?, to end: String?, ongoing: Bool = true) -> ImportItem {
        var item = item
        item.start = start.flatMap(CVParser.yearMonth)
        item.end = end.flatMap(CVParser.yearMonth)
        item.isCurrent = ongoing && item.start != nil && item.end == nil
        return item
    }

    private static func lines(_ text: String?) -> [String] {
        (text ?? "").components(separatedBy: .newlines)
            .map { CVParser.bulletText($0) ?? CVParser.clean($0) }
            .filter { !$0.isBlank }
    }

    /// LinkedIn writes websites as "[PORTFOLIO:https://a.dev,COMPANY:https://b.com]".
    private static func websites(_ text: String) -> [ProfileLink] {
        text.matches(of: /https?:\/\/[^\s,\]]+/).map { match in
            let url = String(match.output)
            let label = url.contains("github") ? "GitHub" : url.contains("linkedin") ? "LinkedIn" : String(localized: "Website")
            return ProfileLink(label: label, url: url)
        }
    }
}
