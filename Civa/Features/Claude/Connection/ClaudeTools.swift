//
//  ClaudeTools.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Answers Claude's tool calls (FR-071, FR-074). Every call is checked against the user's
/// permissions and logged. Only saved, confirmed records are shared (FR-015): each call reads
/// through a fresh context, so unsaved edits and the editor's context are never touched.
enum ClaudeTools {
    static func answer(
        _ request: ClaudeLink.Request,
        container: ModelContainer,
        permissions: ClaudePermissions = .shared
    ) -> ClaudeLink.Reply {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let reply = respond(request, context: context, permissions: permissions)
        try? context.save()
        return reply
    }

    private static func respond(_ request: ClaudeLink.Request, context: ModelContext, permissions: ClaudePermissions) -> ClaudeLink.Reply {
        guard let tool = ClaudeLink.tool(named: request.tool) else {
            return ClaudeLink.Reply(ok: false, text: "Civa doesn't offer the tool \(request.tool).")
        }
        guard let category = tool.category else { return connectionStatus(permissions) }
        guard permissions.canRead(category) else {
            context.insert(ClaudeActivity(
                kind: .denied, tool: tool.name, category: category,
                summary: String(localized: "Refused: \(category.title) isn't shared")
            ))
            return ClaudeLink.Reply(
                ok: false,
                text: "The user hasn't allowed Claude to read \(category.title) in Civa. They can allow it in Civa → Settings → Claude Desktop."
            )
        }
        let result = read(tool.name, arguments: request.arguments, context: context)
        context.insert(ClaudeActivity(kind: .read, tool: tool.name, category: category, summary: result.summary, detail: result.titles.joined(separator: "\n")))
        return ClaudeLink.Reply(ok: result.ok, text: result.text)
    }

    private static func connectionStatus(_ permissions: ClaudePermissions) -> ClaudeLink.Reply {
        let shared = ClaudeCategory.allCases.filter(permissions.canRead).map(\.title)
        let text = shared.isEmpty
            ? "Civa is open and connected, but the user hasn't shared any categories yet. They can choose what Claude may read in Civa → Settings → Claude Desktop."
            : "Civa is open and connected. Claude may read: \(shared.joined(separator: ", ")). Records the user hasn't confirmed yet aren't shared."
        return ClaudeLink.Reply(ok: true, text: text)
    }

    private struct Result {
        var ok = true
        var text: String
        /// For the log: what was read.
        var summary: String
        var titles: [String] = []
    }

    private static func read(_ tool: String, arguments: [String: String], context: ModelContext) -> Result {
        func confirmed<M: ProfileRecord>(_ type: M.Type) -> (records: [M], waiting: Int) {
            let all = (try? context.fetch(FetchDescriptor<M>())) ?? []
            return (all.filter { !$0.needsReview }, all.count(where: \.needsReview))
        }
        func list<M: ProfileRecord>(_ type: M.Type, _ noun: String, sort: (M, M) -> Bool, _ describe: (M) -> String) -> Result {
            let (records, waiting) = confirmed(type)
            let sorted = records.sorted(by: sort)
            var text = sorted.isEmpty ? "No confirmed \(noun) in Civa." : sorted.map(describe).joined(separator: "\n\n")
            if waiting > 0 { text += "\n\n(\(waiting) more awaiting the user's review in Civa aren't shared.)" }
            return Result(text: text, summary: String(localized: "Read \(sorted.count) \(noun)"), titles: sorted.map(\.displayTitle))
        }

        switch tool {
        case "get_personal_info":
            guard let person = confirmed(PersonalInfo.self).records.first else {
                return Result(text: "No confirmed personal information in Civa.", summary: String(localized: "Read personal information (none)"))
            }
            return Result(text: ClaudeText.personal(person), summary: String(localized: "Read personal information"), titles: [person.displayTitle])
        case "list_experience":
            return list(Experience.self, String(localized: "experience records"), sort: { recency($0) > recency($1) }, ClaudeText.experience)
        case "list_education":
            return list(Education.self, String(localized: "education records"), sort: {
                YearMonth.recency(start: $0.start, end: $0.end) > YearMonth.recency(start: $1.start, end: $1.end)
            }, ClaudeText.education)
        case "list_projects":
            return list(Project.self, String(localized: "projects"), sort: {
                YearMonth.recency(start: $0.start, end: $0.end) > YearMonth.recency(start: $1.start, end: $1.end)
            }, ClaudeText.project)
        case "list_achievements_and_certifications":
            var achievements = list(Achievement.self, String(localized: "achievements"), sort: { ($0.date ?? .distantFuture) > ($1.date ?? .distantFuture) }, ClaudeText.achievement)
            let certifications = list(Certification.self, String(localized: "certifications"), sort: { ($0.issued ?? .distantFuture) > ($1.issued ?? .distantFuture) }, ClaudeText.certification)
            achievements.text = "ACHIEVEMENTS\n\n\(achievements.text)\n\nCERTIFICATIONS\n\n\(certifications.text)"
            achievements.summary += ", " + certifications.summary
            achievements.titles += certifications.titles
            return achievements
        case "list_skills":
            let skills = confirmed(Skill.self).records
            let groups = Dictionary(grouping: skills) { $0.category.isBlank ? String(localized: "Other") : $0.category }
            let text = groups.keys.sorted().map { category in
                "\(category): " + groups[category, default: []].map { [$0.name, $0.type.map { "(\($0.title))" }].compactMap(\.self).joined(separator: " ") }.sorted().joined(separator: ", ")
            }.joined(separator: "\n")
            return Result(text: text.isEmpty ? "No confirmed skills in Civa." : text, summary: String(localized: "Read \(skills.count) skills"), titles: skills.map(\.name))
        case "list_resumes":
            let resumes = ((try? context.fetch(FetchDescriptor<Resume>())) ?? []).sorted { $0.updatedAt > $1.updatedAt }
            let text = resumes.map { resume in
                "[resume_id: \(resume.id)] \(resume.displayTitle)\(resume.isMaster ? " (Master Resume)" : "")"
                    + (resume.targetPosition.isBlank ? "" : "\nTarget: \(resume.targetPosition)")
                    + "\nUpdated \(resume.updatedAt.formatted(date: .abbreviated, time: .omitted))"
            }.joined(separator: "\n\n")
            return Result(text: text.isEmpty ? "No resumes in Civa." : text, summary: String(localized: "Listed \(resumes.count) resumes"), titles: resumes.map(\.displayTitle))
        case "get_resume":
            guard let id = arguments["resume_id"].flatMap(UUID.init(uuidString:)),
                  let resume = try? context.fetch(FetchDescriptor<Resume>(predicate: #Predicate { $0.id == id })).first else {
                return Result(ok: false, text: "No resume with that id. Call list_resumes for the ids.", summary: String(localized: "Asked for a resume that doesn't exist"))
            }
            return Result(text: ClaudeText.resume(resume), summary: String(localized: "Read the resume “\(resume.displayTitle)”"), titles: [resume.displayTitle])
        case "list_applications":
            let applications = ((try? context.fetch(FetchDescriptor<JobApplication>())) ?? []).sorted { $0.updatedAt > $1.updatedAt }
            let text = applications.map(ClaudeText.applicationSummary).joined(separator: "\n\n")
            return Result(text: text.isEmpty ? "No applications in Civa." : text, summary: String(localized: "Listed \(applications.count) applications"), titles: applications.map(\.displayTitle))
        case "get_application":
            guard let id = arguments["application_id"].flatMap(UUID.init(uuidString:)),
                  let application = try? context.fetch(FetchDescriptor<JobApplication>(predicate: #Predicate { $0.id == id })).first else {
                return Result(ok: false, text: "No application with that id. Call list_applications for the ids.", summary: String(localized: "Asked for an application that doesn't exist"))
            }
            let text = ClaudeText.applicationSummary(application)
                + "\n\nJob description:\n" + (application.jobDescription.isBlank ? "(none saved)" : application.jobDescription)
            return Result(text: text, summary: String(localized: "Read the application “\(application.displayTitle)”"), titles: [application.displayTitle])
        default:
            return Result(ok: false, text: "Civa doesn't offer the tool \(tool).", summary: tool)
        }
    }

    private static func recency(_ experience: Experience) -> YearMonth {
        YearMonth.recency(start: experience.start, end: experience.end, isCurrent: experience.isCurrent)
    }
}

/// Plain text Claude reads well: one record per block, with ids for later tools.
enum ClaudeText {
    static func personal(_ person: PersonalInfo) -> String {
        lines([
            "Name: \(person.fullName)",
            field("Headline", person.headline),
            field("Summary", person.summary),
            field("Email", person.email),
            field("Phone", person.phone),
            field("Location", person.location),
        ] + person.links.map { "\($0.label.isBlank ? "Link" : $0.label): \($0.url)" })
    }

    static func experience(_ experience: Experience) -> String {
        let kind = experience.kind == .professional ? "Professional" : "Organizational"
        return lines([
            "[\(kind) · id: \(experience.id)] \(experience.role) — \(experience.organization)",
            dates(YearMonth.rangeText(start: experience.start, end: experience.end, isCurrent: experience.isCurrent)),
            field("Type", [experience.employmentType?.title, experience.organizationType?.title].compactMap(\.self).joined()),
            field("Work arrangement", experience.workArrangement?.title ?? ""),
            field("Location", experience.location),
            field("Recognition", experience.recognition),
            field("Description", experience.details),
            bullets("Results", experience.impacts),
            field("Skills used", experience.skills.map(\.name).sorted().joined(separator: ", ")),
        ])
    }

    static func education(_ education: Education) -> String {
        lines([
            "[Education · id: \(education.id)] \(education.institution)",
            field("Level", education.degreeLevel?.title ?? ""),
            field("Degree", [education.degree, education.fieldOfStudy].filter { !$0.isBlank }.joined(separator: ", ")),
            dates(YearMonth.rangeText(start: education.start, end: education.end)),
            field("Grade", education.gradeText),
            field("Thesis", education.thesis),
            field("Relevant coursework", education.coursework.joined(separator: ", ")),
            field("Honors", education.honors),
            field("Description", education.details),
        ])
    }

    static func project(_ project: Project) -> String {
        lines([
            "[Project · id: \(project.id)] \(project.name)",
            field("Role", project.role),
            dates(YearMonth.rangeText(start: project.start, end: project.end)),
            field("Link", project.url),
            field("Repository", project.repositoryURL),
            field("Description", project.details),
            bullets("Results", project.impacts),
            field("Skills used", project.skills.map(\.name).sorted().joined(separator: ", ")),
        ])
    }

    static func achievement(_ achievement: Achievement) -> String {
        lines([
            "[Achievement · id: \(achievement.id)] \(achievement.title)",
            field("Placement", achievement.placement),
            field("Issuer", achievement.issuer),
            dates(achievement.date?.formatted() ?? ""),
            field("Description", achievement.details),
        ])
    }

    static func certification(_ certification: Certification) -> String {
        lines([
            "[Certification · id: \(certification.id)] \(certification.name)",
            field("Issuer", certification.issuer),
            field("Issued", certification.issued?.formatted() ?? ""),
            field("Expires", certification.expires?.formatted() ?? ""),
            field("Credential", certification.credentialURL),
        ])
    }

    static func applicationSummary(_ application: JobApplication) -> String {
        lines([
            "[application_id: \(application.id)] \(application.position) at \(application.company)",
            "Status: \(application.status.title)",
            field("Applied", application.applicationDate?.formatted(date: .abbreviated, time: .omitted) ?? ""),
            field("Resume sent", application.resume?.displayTitle ?? ""),
        ])
    }

    static func resume(_ resume: Resume) -> String {
        let document = resume.document
        let header = document.header
        var parts = [
            "[resume_id: \(resume.id)] \(resume.displayTitle)\(resume.isMaster ? " (Master Resume)" : "")",
            field("Target position", resume.targetPosition),
            "",
            header.fullName,
            header.headline,
            ([header.location, header.email, header.phone] + header.links.map(\.url)).filter { !$0.isBlank }.joined(separator: " · "),
        ]
        if !document.summary.isBlank { parts += ["", document.summary] }
        for section in document.sections where !section.entries.isEmpty {
            parts += ["", section.title.uppercased()]
            for entry in section.entries {
                if section.kind == .skills {
                    parts.append([entry.title, entry.subtitle].filter { !$0.isBlank }.joined(separator: ": "))
                    continue
                }
                parts.append([entry.title, entry.grade ?? "", entry.datesText(document.format.dateStyle ?? .short)].filter { !$0.isBlank }.joined(separator: " | "))
                if !entry.subtitle.isBlank { parts.append(entry.subtitle) }
                if let thesis = entry.thesis, !thesis.isBlank { parts.append("Thesis: \(thesis)") }
                if let coursework = entry.coursework, !coursework.isEmpty { parts.append("Relevant Coursework: \(coursework.joined(separator: ", "))") }
                parts += entry.bullets.filter { !$0.isBlank }.map { "- \($0)" }
            }
        }
        return lines(parts, keepingBlanks: true)
    }

    private static func field(_ label: String, _ value: String) -> String {
        value.isBlank ? "" : "\(label): \(value)"
    }

    private static func dates(_ text: String) -> String {
        field("Dates", text)
    }

    private static func bullets(_ label: String, _ items: [String]) -> String {
        let items = items.filter { !$0.isBlank }
        return items.isEmpty ? "" : "\(label):\n" + items.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func lines(_ parts: [String], keepingBlanks: Bool = false) -> String {
        (keepingBlanks ? parts : parts.filter { !$0.isBlank }).joined(separator: "\n")
    }
}
