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
            document.header = ResumeHeader(
                fullName: person.fullName, headline: person.headline, email: person.email,
                phone: person.phone, location: person.location, links: person.links
            )
        }

        let experiences = confirmed(selection.experiences).sorted { recency($0) > recency($1) }
        let sections: [ResumeSection] = [
            ResumeSection(kind: .experience, entries: experiences.filter { $0.kind == .professional }.map(entry)),
            ResumeSection(kind: .organizational, entries: experiences.filter { $0.kind == .organizational }.map(entry)),
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
        document.sections = sections.filter { !$0.entries.isEmpty }
        return document
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

    private static func entry(_ experience: Experience) -> ResumeEntry {
        ResumeEntry(
            sourceID: experience.id,
            title: experience.role,
            subtitle: joined([experience.organization, experience.location]),
            dates: YearMonth.rangeText(start: experience.start, end: experience.end, isCurrent: experience.isCurrent),
            bullets: bullets(impacts: experience.impacts, details: experience.details)
        )
    }

    private static func entry(_ education: Education) -> ResumeEntry {
        let degree = joined([education.degree, education.fieldOfStudy], ", ")
        return ResumeEntry(
            sourceID: education.id,
            title: degree.isEmpty ? education.institution : degree,
            subtitle: joined([degree.isEmpty ? "" : education.institution, education.location]),
            dates: YearMonth.rangeText(start: education.start, end: education.end),
            bullets: [
                education.grade.isBlank ? "" : String(localized: "Grade: \(education.grade)"),
                education.details,
            ].filter { !$0.isBlank }
        )
    }

    private static func entry(_ project: Project) -> ResumeEntry {
        ResumeEntry(
            sourceID: project.id,
            title: project.name,
            subtitle: joined([project.role, project.url]),
            dates: YearMonth.rangeText(start: project.start, end: project.end),
            bullets: bullets(impacts: project.impacts, details: project.details)
        )
    }

    private static func entry(_ achievement: Achievement) -> ResumeEntry {
        ResumeEntry(
            sourceID: achievement.id,
            title: achievement.title,
            subtitle: achievement.issuer,
            dates: achievement.date?.formatted() ?? "",
            bullets: [achievement.details].filter { !$0.isBlank }
        )
    }

    private static func entry(_ certification: Certification) -> ResumeEntry {
        ResumeEntry(
            sourceID: certification.id,
            title: certification.name,
            subtitle: certification.issuer,
            dates: certification.issued?.formatted() ?? ""
        )
    }

    /// One line per category: "Languages: Swift, Kotlin". Uncategorized skills share a line.
    private static func skillLines(_ skills: [Skill]) -> [ResumeEntry] {
        Dictionary(grouping: skills) { $0.category.trimmingCharacters(in: .whitespaces) }
            .sorted { $0.key.isEmpty == $1.key.isEmpty ? $0.key < $1.key : !$0.key.isEmpty }
            .map { category, skills in
                ResumeEntry(title: category, subtitle: skills.map(\.name).sorted().joined(separator: ", "))
            }
    }
}
