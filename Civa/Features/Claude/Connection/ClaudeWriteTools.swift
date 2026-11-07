//
//  ClaudeWriteTools.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Claude's write tools (FR-072, FR-073). None of them changes the user's data: each stores a
/// suggestion the user applies or dismisses in Civa, or a draft resume they keep or discard.
/// Each needs Suggest for its category and is logged (FR-074).
enum ClaudeWriteTools {
    typealias Reply = ClaudeLink.Reply

    static func respond(_ request: ClaudeLink.Request, context: ModelContext, permissions: ClaudePermissions) -> Reply {
        let arguments = request.arguments
        switch request.tool {
        case "get_pending_requests": return pendingRequests(context)
        case "finish_request": return finish(arguments, context)
        case "suggest_resume_edit": return resumeEdit(arguments, context, permissions)
        case "suggest_profile_edit": return recordEdit(arguments, context, permissions)
        case "create_resume_draft": return resumeDraft(arguments, context, permissions)
        case "suggest_profile_records": return profileImport(arguments, context, permissions)
        default: return Reply(ok: false, text: "Civa doesn't offer the tool \(request.tool).")
        }
    }

    // MARK: - Requests

    private static func pendingRequests(_ context: ModelContext) -> Reply {
        let pending = ClaudeRequest.Status.pending.rawValue
        let requests = (try? context.fetch(FetchDescriptor<ClaudeRequest>(
            predicate: #Predicate { $0.statusRaw == pending }, sortBy: [SortDescriptor(\.createdAt)]
        ))) ?? []
        context.insert(ClaudeActivity(
            kind: .read, tool: "get_pending_requests", category: nil,
            summary: String(localized: "Read \(requests.count) pending requests"), detail: requests.map(\.title).joined(separator: "\n")
        ))
        guard !requests.isEmpty else {
            return Reply(ok: true, text: "No pending requests. The user can queue one with an Ask Claude button in Civa.")
        }
        return Reply(ok: true, text: requests.map(task).joined(separator: "\n\n"))
    }

    /// What Claude should do for one request, and with which tools.
    static func task(_ request: ClaudeRequest) -> String {
        let id = "request_id: \(request.id)"
        let rule = "Offer 2–3 versions per change with short labels (such as Concise, With Numbers, Job Keywords) using options or summary_options; the user picks one. Keep every fact, number, date, and employer; change only wording and order. If something the task needs isn't shared, call finish_request with failed \"true\" and say what to allow in Civa."
        let body = switch request.kind {
        case .tailorResume:
            "Tailor the resume \(request.targetID) (“\(request.targetTitle)”) to the job in application \(request.applicationID?.uuidString ?? "?"). Read them with get_resume and get_application, then send one suggest_resume_edit with a new summary and reworded entry bullets that match the job."
        case .writeSummary:
            "Write a 2–3 sentence professional summary for the resume \(request.targetID) (“\(request.targetTitle)”), using only what's in it. Read it with get_resume and send suggest_resume_edit with the summary."
        case .improveBullets:
            "Improve the impact lines of the record \(request.targetID) (“\(request.targetTitle)”): lead with the result, cut filler, and quantify only with numbers already there. Read it with list_experience or list_projects and send suggest_profile_edit with field impacts and the new lines."
        case .draftResume:
            "Draft a resume for the application \(request.targetID) (“\(request.targetTitle)”). Read the job with get_application and the Career Profile with the list tools, pick the relevant records, and call create_resume_draft with application_id, the records, a summary, and bullets that fit the job."
        }
        return "[\(id)] \(request.title)\n\(body)\n\(rule)"
    }

    private static func finish(_ arguments: [String: String], _ context: ModelContext) -> Reply {
        guard let request = fetchRequest(arguments["request_id"], context) else {
            return Reply(ok: false, text: "No request with that id. Call get_pending_requests for the ids.")
        }
        request.status = arguments["failed"] == "true" ? .failed : .answered
        request.answeredAt = .now
        request.note = arguments["note"] ?? ""
        context.insert(ClaudeActivity(
            kind: .suggested, tool: "finish_request", category: nil,
            summary: request.status == .failed ? String(localized: "Couldn't finish: \(request.title)") : String(localized: "Finished: \(request.title)"),
            detail: request.note
        ))
        return Reply(ok: true, text: "Done. The user sees your note in Civa.")
    }

    private static func fetchRequest(_ id: String?, _ context: ModelContext) -> ClaudeRequest? {
        guard let id = id.flatMap(UUID.init(uuidString:)) else { return nil }
        return try? context.fetch(FetchDescriptor<ClaudeRequest>(predicate: #Predicate { $0.id == id })).first
    }

    /// Saves a suggestion, closes the request it answers, and logs it.
    private static func propose(_ proposal: ClaudeProposal, tool: String, summary: String, context: ModelContext) -> Reply {
        context.insert(proposal)
        if let request = fetchRequest(proposal.requestID?.uuidString, context), request.status == .pending {
            request.status = .answered
            request.answeredAt = .now
        }
        context.insert(ClaudeActivity(kind: .suggested, tool: tool, category: proposal.category, summary: summary, detail: proposal.note))
        return Reply(ok: true, text: "Sent to Civa. The user reviews it there; nothing changes until they apply it.")
    }

    private static func refuse(_ category: ClaudeCategory, tool: String, _ context: ModelContext) -> Reply {
        context.insert(ClaudeActivity(kind: .denied, tool: tool, category: category, summary: String(localized: "Refused: suggestions for \(category.title) aren't allowed")))
        return Reply(ok: false, text: "The user hasn't allowed Claude to suggest changes to \(category.title) in Civa. They can allow it in Civa → Settings → Claude Desktop.")
    }

    // MARK: - Resume edits

    private struct EntryInput: Decodable {
        let entryID: String
        let title: String?
        let subtitle: String?
        let bullets: [String]?
        let options: [VersionInput]?

        enum CodingKeys: String, CodingKey {
            case entryID = "entry_id", title, subtitle, bullets, options
        }
    }

    /// One option as Claude sends it. Entries send `bullets`, impacts send `lines`.
    private struct VersionInput: Decodable {
        let label: String
        let text: String?
        let title: String?
        let subtitle: String?
        let bullets: [String]?
        let lines: [String]?
    }

    /// A message Claude can act on.
    private struct OptionsError: Error {
        let message: String
    }

    /// 2–3 labeled options, each with a value; nil when Claude sent none.
    private static func options(
        _ inputs: [VersionInput]?, isUsable: (ClaudeProposal.Version) -> Bool
    ) throws -> [ClaudeProposal.Version]? {
        guard let inputs else { return nil }
        guard (2...3).contains(inputs.count) else { throw OptionsError(message: "Send 2 or 3 options per change, each with a short label.") }
        let versions = inputs.map {
            ClaudeProposal.Version(
                label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines), text: $0.text, title: $0.title,
                subtitle: $0.subtitle, lines: ($0.bullets ?? $0.lines)?.filter { !$0.isBlank }
            )
        }
        guard versions.allSatisfy({ !$0.label.isBlank && isUsable($0) }) else {
            throw OptionsError(message: "Every option needs a short label, like “Concise”, and a value.")
        }
        return versions
    }

    /// Options sent as a JSON argument; an argument that isn't valid JSON is an error, not "none".
    private static func options(
        _ arguments: [String: String], _ key: String, isUsable: (ClaudeProposal.Version) -> Bool
    ) throws -> [ClaudeProposal.Version]? {
        guard let raw = arguments[key] else { return nil }
        guard let inputs = decode([VersionInput].self, raw) else {
            throw OptionsError(message: "\(key) must be a list of objects with a label and a value.")
        }
        return try options(inputs, isUsable: isUsable)
    }

    private static func resumeEdit(_ arguments: [String: String], _ context: ModelContext, _ permissions: ClaudePermissions) -> Reply {
        let tool = "suggest_resume_edit"
        guard permissions.canSuggest(.resumes) else { return refuse(.resumes, tool: tool, context) }
        guard let id = arguments["resume_id"].flatMap(UUID.init(uuidString:)),
              let resume = try? context.fetch(FetchDescriptor<Resume>(predicate: #Predicate { $0.id == id })).first
        else { return Reply(ok: false, text: "No resume with that id. Call list_resumes for the ids.") }

        let known = Set(resume.document.sections.flatMap(\.entries).map(\.id))
        let inputs = decode([EntryInput].self, arguments["entries"]) ?? []
        let entries: [ClaudeProposal.ResumeEdit.Entry]
        let summaryOptions: [ClaudeProposal.Version]?
        do {
            summaryOptions = try options(arguments, "summary_options") { $0.text?.isBlank == false }
            entries = try inputs.compactMap { input in
                guard let entryID = UUID(uuidString: input.entryID), known.contains(entryID) else { return nil }
                let versions = try options(input.options) { $0.title?.isBlank == false || $0.subtitle?.isBlank == false || $0.lines?.isEmpty == false }
                return .init(
                    entryID: entryID, title: input.title, subtitle: input.subtitle,
                    bullets: input.bullets?.filter { !$0.isBlank }, options: versions
                )
            }
        } catch let error as OptionsError {
            return Reply(ok: false, text: error.message)
        } catch {
            return Reply(ok: false, text: error.localizedDescription)
        }
        let summary = summaryOptions == nil ? arguments["summary"].flatMap { $0.isBlank ? nil : $0 } : nil
        guard summary != nil || summaryOptions != nil || !entries.isEmpty else {
            return Reply(ok: false, text: "Nothing to suggest: send a summary or entries with entry ids from get_resume.")
        }
        let proposal = ClaudeProposal(
            kind: .resumeEdit, targetID: resume.id, targetTitle: resume.displayTitle, category: .resumes,
            requestID: arguments["request_id"].flatMap(UUID.init(uuidString:)), note: arguments["note"] ?? "",
            payload: ClaudeProposal.ResumeEdit(summary: summary, summaryOptions: summaryOptions, entries: entries)
        )
        var reply = propose(proposal, tool: tool, summary: String(localized: "Suggested changes to “\(resume.displayTitle)”"), context: context)
        let skipped = inputs.count - entries.count
        if skipped > 0 { reply.text += " \(skipped) entries were left out because their ids aren't in this resume." }
        return reply
    }

    // MARK: - Profile edits

    private static func recordEdit(_ arguments: [String: String], _ context: ModelContext, _ permissions: ClaudePermissions) -> Reply {
        let tool = "suggest_profile_edit"
        guard let id = arguments["record_id"].flatMap(UUID.init(uuidString:)),
              let field = arguments["field"].flatMap(ClaudeProposal.RecordEdit.Field.init(rawValue:))
        else { return Reply(ok: false, text: "Send a record_id and a field: impacts, details, summary, or headline.") }

        let target: (title: String, category: ClaudeCategory, fields: Set<ClaudeProposal.RecordEdit.Field>)?
        if let record = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first {
            target = (record.displayTitle, .experience, [.impacts, .details])
        } else if let record = try? context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })).first {
            target = (record.displayTitle, .projects, [.impacts, .details])
        } else if let record = try? context.fetch(FetchDescriptor<PersonalInfo>(predicate: #Predicate { $0.id == id })).first {
            target = (record.displayTitle, .personal, [.summary, .headline])
        } else {
            target = nil
        }
        guard let target else { return Reply(ok: false, text: "No experience, project, or personal information with that id.") }
        guard permissions.canSuggest(target.category) else { return refuse(target.category, tool: tool, context) }
        guard target.fields.contains(field) else {
            return Reply(ok: false, text: "That record's \(field.rawValue) can't be suggested. Allowed: \(target.fields.map(\.rawValue).sorted().joined(separator: ", ")).")
        }
        let lines = decode([String].self, arguments["lines"])?.filter { !$0.isBlank }
        let text = arguments["text"]
        let versions: [ClaudeProposal.Version]?
        do {
            versions = try options(arguments, "options") { field == .impacts ? $0.lines?.isEmpty == false : $0.text?.isBlank == false }
        } catch let error as OptionsError {
            return Reply(ok: false, text: error.message)
        } catch {
            return Reply(ok: false, text: error.localizedDescription)
        }
        guard versions != nil || (field == .impacts ? lines?.isEmpty == false : text?.isBlank == false) else {
            return Reply(ok: false, text: field == .impacts ? "Send the new impacts as lines, or options with lines." : "Send the new \(field.rawValue) as text, or options with text.")
        }
        let proposal = ClaudeProposal(
            kind: .recordEdit, targetID: id, targetTitle: target.title, category: target.category,
            requestID: arguments["request_id"].flatMap(UUID.init(uuidString:)), note: arguments["note"] ?? "",
            payload: ClaudeProposal.RecordEdit(
                field: field, text: versions != nil || field == .impacts ? nil : text,
                lines: versions != nil || field != .impacts ? nil : lines, options: versions
            )
        )
        return propose(proposal, tool: tool, summary: String(localized: "Suggested a new \(field.rawValue) for “\(target.title)”"), context: context)
    }

    // MARK: - Draft resumes

    private struct RecordInput: Decodable {
        let recordID: String
        let bullets: [String]?

        enum CodingKeys: String, CodingKey {
            case recordID = "record_id", bullets
        }
    }

    private static func resumeDraft(_ arguments: [String: String], _ context: ModelContext, _ permissions: ClaudePermissions) -> Reply {
        let tool = "create_resume_draft"
        guard permissions.canSuggest(.resumes) else { return refuse(.resumes, tool: tool, context) }
        let inputs = decode([RecordInput].self, arguments["records"]) ?? []
        let ids = Set(inputs.compactMap { UUID(uuidString: $0.recordID) })
        func pick<M: ProfileRecord>(_ type: M.Type, _ category: ClaudeCategory) -> [M] {
            guard permissions.canRead(category) else { return [] }
            return ((try? context.fetch(FetchDescriptor<M>())) ?? []).filter { !$0.needsReview && ids.contains(($0 as? any DocumentOwner)?.id ?? UUID()) }
        }
        let experiences = pick(Experience.self, .experience)
        let education = pick(Education.self, .education)
        let projects = pick(Project.self, .projects)
        let achievements = pick(Achievement.self, .recognition)
        let certifications = pick(Certification.self, .recognition)
        let found = experiences.count + education.count + projects.count + achievements.count + certifications.count
        guard found > 0 else {
            return Reply(ok: false, text: "None of those records can be used: send ids of confirmed records from categories the user shares.")
        }
        let names = Set((decode([String].self, arguments["skills"]) ?? []).map { $0.lowercased() })
        let allSkills = permissions.canRead(.skills) ? ((try? context.fetch(FetchDescriptor<Skill>())) ?? []).filter { !$0.needsReview } : []
        let skills = names.isEmpty
            ? allSkills.filter { skill in skill.experiences.contains { experiences.contains($0) } || skill.projects.contains { projects.contains($0) } }
            : allSkills.filter { names.contains($0.name.lowercased()) }
        let person = (try? context.fetch(FetchDescriptor<PersonalInfo>()))?.first

        var document = ResumeBuilder.document(from: .init(
            personalInfo: person, experiences: experiences, education: education, projects: projects,
            achievements: achievements, certifications: certifications, skills: skills
        ))
        let bullets = Dictionary(inputs.compactMap { input in
            UUID(uuidString: input.recordID).flatMap { id in input.bullets.map { (id, $0.filter { !$0.isBlank }) } }
        }, uniquingKeysWith: { first, _ in first })
        for s in document.sections.indices {
            for e in document.sections[s].entries.indices {
                if let id = document.sections[s].entries[e].sourceID, let lines = bullets[id], !lines.isEmpty {
                    document.sections[s].entries[e].bullets = lines
                    document.sections[s].entries[e].claudeTouched = true
                }
            }
        }
        if let summary = arguments["summary"], !summary.isBlank {
            document.summary = summary
            document.claudeTouchedSummary = true
        }
        let master = (try? context.fetch(FetchDescriptor<Resume>(predicate: #Predicate { $0.isMaster })))?.first
        if let master { document.format = master.document.format }

        let applicationID = arguments["application_id"].flatMap(UUID.init(uuidString:))
        let application = applicationID.flatMap { id in try? context.fetch(FetchDescriptor<JobApplication>(predicate: #Predicate { $0.id == id })).first }
        let title = arguments["title"].flatMap { $0.isBlank ? nil : $0 } ?? String(localized: "Draft from Claude")
        let resume = Resume(
            title: title,
            targetPosition: arguments["target_position"] ?? application?.position ?? "",
            jobDescription: application?.jobDescription ?? "",
            document: document
        )
        resume.isClaudeDraft = true
        context.insert(resume)
        let proposal = ClaudeProposal(
            kind: .resumeDraft, targetID: resume.id, targetTitle: title, category: .resumes,
            requestID: arguments["request_id"].flatMap(UUID.init(uuidString:)), note: arguments["note"] ?? "",
            payload: [String: String]()
        )
        var reply = propose(proposal, tool: tool, summary: String(localized: "Drafted the resume “\(title)”"), context: context)
        reply.text = "Drafted “\(title)” in Civa with \(found) records. It's waiting in Resumes for the user to keep or discard."
        if ids.count > found { reply.text += " \(ids.count - found) ids were left out: they're unconfirmed, not shared, or not found." }
        return reply
    }

    // MARK: - Import

    static func importCategory(_ name: String) -> (ImportCategory, ClaudeCategory)? {
        switch name.lowercased() {
        case "experience", "professional": (.experience, .experience)
        case "organizational", "organization": (.organizational, .experience)
        case "education": (.education, .education)
        case "projects", "project": (.projects, .projects)
        case "achievements", "achievement": (.achievements, .recognition)
        case "certifications", "certification": (.certifications, .recognition)
        case "skills", "skill": (.skills, .skills)
        default: nil
        }
    }

    private static func profileImport(_ arguments: [String: String], _ context: ModelContext, _ permissions: ClaudePermissions) -> Reply {
        let tool = "suggest_profile_records"
        let records = (decode([ClaudeProposal.ProfileImport.Record].self, arguments["records"]) ?? []).filter { importCategory($0.category) != nil && !$0.title.isBlank }
        guard !records.isEmpty else {
            return Reply(ok: false, text: "No usable records. Each needs a title and a category: experience, organizational, education, projects, achievements, certifications, or skills.")
        }
        let categories = Set(records.compactMap { importCategory($0.category)?.1 })
        if let blocked = categories.sorted(by: { $0.rawValue < $1.rawValue }).first(where: { !permissions.canSuggest($0) }) {
            return refuse(blocked, tool: tool, context)
        }
        let source = arguments["source"].flatMap { $0.isBlank ? nil : $0 } ?? String(localized: "Claude")
        let proposal = ClaudeProposal(
            kind: .profileImport, targetID: nil, targetTitle: source, category: categories.first ?? .experience,
            requestID: nil, note: arguments["note"] ?? "", payload: ClaudeProposal.ProfileImport(source: source, records: records)
        )
        return propose(proposal, tool: tool, summary: String(localized: "Sent \(records.count) records from \(source) for review"), context: context)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ text: String?) -> T? {
        text.flatMap { try? JSONDecoder().decode(type, from: Data($0.utf8)) }
    }
}
