//
//  ResumeBuilder.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Turns chosen Career Profile records into a resume's own copy (FR-031). Records that still
/// need review are skipped, since unconfirmed data isn't used as fact (FR-015). Custom fields
/// stay in the profile (FR-012).
enum ResumeBuilder {
    struct Selection {
        var personalInfo: PersonalInfo?
        var experiences: [Experience] = []
        var education: [Education] = []
        var projects: [Project] = []
        var achievements: [Achievement] = []
        var certifications: [Certification] = []
        var skills: [Skill] = []
    }

    static func document(from selection: Selection) -> ResumeDocument {
        var document = ResumeDocument()
        if let person = selection.personalInfo, !person.needsReview {
            document.header = header(from: person)
            document.headerSource = document.header
            document.summary = person.summary
        }

        let experiences = confirmed(selection.experiences).sorted { recency($0) > recency($1) }
        let sections: [ResumeSection] = [
            ResumeSection(kind: .experience, entries: experiences.filter { $0.kind == .professional }.map(entry)),
        ]
        // Leadership and volunteer roles get their own sections; the rest stay Organizational Experience.
        let organizational = experiences.filter { $0.kind == .organizational }
        let groups: [(OrganizationType?, String?)] = [
            (.leadership, String(localized: "Leadership Experience")),
            (nil, nil),
            (.volunteer, String(localized: "Volunteer Experience")),
        ]
        let organizationalSections = groups.map { type, heading in
            ResumeSection(
                kind: .organizational,
                entries: organizational.filter { $0.organizationType.resumeGroup == type }.map(entry),
                heading: heading
            )
        }
        let rest: [ResumeSection] = [
            ResumeSection(kind: .education, entries: confirmed(selection.education)
                .sorted { YearMonth.recency(start: $0.start, end: $0.end) > YearMonth.recency(start: $1.start, end: $1.end) }
                .map(entry)),
            ResumeSection(kind: .projects, entries: confirmed(selection.projects)
                .sorted { YearMonth.recency(start: $0.start, end: $0.end) > YearMonth.recency(start: $1.start, end: $1.end) }
                .map(entry)),
            ResumeSection(kind: .achievements, entries: confirmed(selection.achievements)
                .sorted { ($0.date ?? .distantFuture) > ($1.date ?? .distantFuture) }
                .map(entry)),
            ResumeSection(kind: .certifications, entries: confirmed(selection.certifications)
                .sorted { ($0.issued ?? .distantFuture) > ($1.issued ?? .distantFuture) }
                .map(entry)),
            ResumeSection(kind: .skills, entries: skillLines(confirmed(selection.skills))),
        ]
        document.sections = (sections.prefix(1) + organizationalSections + rest).filter { !$0.entries.isEmpty }
        // Remember what each entry was copied from, for Suggested Changes (FR-042).
        for s in document.sections.indices {
            for e in document.sections[s].entries.indices where document.sections[s].entries[e].sourceID != nil {
                document.sections[s].entries[e].sourceCopy = document.sections[s].entries[e].asSourceCopy
            }
        }
        return document
    }

    static func header(from person: PersonalInfo) -> ResumeHeader {
        ResumeHeader(
            fullName: person.fullName, headline: person.headline, email: person.email,
            phone: person.phone, location: person.location, links: person.links
        )
    }

    /// How a profile record reads in a resume. Skills are grouped into lines, so they have none.
    static func entry(for record: any ProfileRecord) -> ResumeEntry? {
        switch record {
        case let record as Experience: entry(record)
        case let record as Education: entry(record)
        case let record as Project: entry(record)
        case let record as Achievement: entry(record)
        case let record as Certification: entry(record)
        default: nil
        }
    }

    private static func confirmed<M: ProfileRecord>(_ records: [M]) -> [M] {
        records.filter { !$0.needsReview }
    }

    private static func recency(_ experience: Experience) -> YearMonth {
        YearMonth.recency(start: experience.start, end: experience.end, isCurrent: experience.isCurrent)
    }

    private static func joined(_ parts: [String], _ separator: String = " · ") -> String {
        parts.filter { !$0.isBlank }.joined(separator: separator)
    }

    /// Impacts become bullets; with none, the description stands in.
    private static func bullets(impacts: [String], details: String) -> [String] {
        let impacts = impacts.filter { !$0.isBlank }
        return impacts.isEmpty ? [details].filter { !$0.isBlank } : impacts
    }

    /// nil for empty text, so entries without a value don't carry an empty one.
    private static func text(_ value: String) -> String? {
        value.isBlank ? nil : value
    }

    private static func entry(_ experience: Experience) -> ResumeEntry {
        ResumeEntry(
            sourceID: experience.id,
            title: experience.role,
            subtitle: joined([experience.organization, experience.location]),
            dates: YearMonth.rangeText(start: experience.start, end: experience.end, isCurrent: experience.isCurrent),
            bullets: bullets(impacts: experience.impacts, details: experience.details),
            employmentType: experience.employmentType?.title,
            start: experience.start,
            end: experience.isCurrent ? nil : experience.end,
            isCurrent: experience.isCurrent,
            workArrangement: experience.workArrangement?.title,
            proofURL: text(experience.proofLink),
            location: text(experience.location)
        )
    }

    private static func entry(_ education: Education) -> ResumeEntry {
        let degree = joined([education.degree, education.fieldOfStudy], ", ")
        return ResumeEntry(
            sourceID: education.id,
            title: degree.isEmpty ? education.institution : degree,
            subtitle: joined([degree.isEmpty ? "" : education.institution, education.location]),
            dates: YearMonth.rangeText(start: education.start, end: education.end),
            bullets: [education.honors, education.details].filter { !$0.isBlank },
            start: education.start,
            end: education.end,
            grade: text(education.numericGrade?.formatted(locale: resumeLocale, separator: "/") ?? education.grade),
            thesis: text(education.thesis),
            coursework: education.coursework.filter { !$0.isBlank }.nilIfEmpty,
            proofURL: text(education.proofLink),
            location: text(education.location)
        )
    }

    private static func entry(_ project: Project) -> ResumeEntry {
        ResumeEntry(
            sourceID: project.id,
            title: project.name,
            subtitle: joined([project.role, project.url]),
            dates: YearMonth.rangeText(start: project.start, end: project.end),
            bullets: bullets(impacts: project.impacts, details: project.details),
            start: project.start,
            end: project.end,
            proofURL: text(project.proofLink)
        )
    }

    /// Resumes print grades with a decimal point, whatever the Mac's region.
    // ponytail: fixed to English number style; follow a per-resume language once resumes have one.
    private static let resumeLocale = Locale(identifier: "en_US_POSIX")

    private static func entry(_ achievement: Achievement) -> ResumeEntry {
        ResumeEntry(
            sourceID: achievement.id,
            title: joined([achievement.placement, achievement.title], ", "),
            subtitle: achievement.issuer,
            dates: achievement.date?.formatted() ?? "",
            bullets: [achievement.details].filter { !$0.isBlank },
            start: achievement.date,
            proofURL: text(achievement.proofLink)
        )
    }

    private static func entry(_ certification: Certification) -> ResumeEntry {
        ResumeEntry(
            sourceID: certification.id,
            title: certification.name,
            subtitle: certification.issuer,
            dates: certification.issued?.formatted() ?? "",
            start: certification.issued,
            proofURL: text(certification.proofLink)
        )
    }

    /// One line per category: "Languages: Swift, Kotlin". Uncategorized skills share a line.
    /// Each line remembers its skills, so later additions, removals, and renames can be suggested (FR-042).
    private static func skillLines(_ skills: [Skill]) -> [ResumeEntry] {
        Dictionary(grouping: skills) { skillCategory($0.category) }
            .sorted { $0.key.isEmpty == $1.key.isEmpty ? $0.key < $1.key : !$0.key.isEmpty }
            .map { category, skills in
                var entry = ResumeEntry(title: category, subtitle: skillList(skills.map(\.name)))
                entry.sourceCopy = skillLineCopy(category: category, skills: Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0.name) }))
                return entry
            }
    }

    static func skillCategory(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespaces)
    }

    static func skillList(_ names: [String]) -> String {
        names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: ", ")
    }

    /// A skill line as the profile has it: the category, and its skills by id.
    static func skillLineCopy(category: String, skills: [UUID: String]) -> ResumeEntry.SourceCopy {
        ResumeEntry.SourceCopy(title: category, subtitle: skillList(Array(skills.values)), dates: "", bullets: [], skills: skills)
    }
}

private nonisolated extension Array {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}

private extension Optional where Wrapped == OrganizationType {
    /// The organizational section a record goes in: leadership, volunteer, or nil for the rest.
    var resumeGroup: OrganizationType? {
        self == .leadership || self == .volunteer ? self : nil
    }
}
