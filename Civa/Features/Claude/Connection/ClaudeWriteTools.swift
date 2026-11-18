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
        case "list_suggestions": return suggestions(context)
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

    /// Every suggestion Claude sent, newest first, with what the user did with it.
    private static func suggestions(_ context: ModelContext) -> Reply {
        let proposals = (try? context.fetch(FetchDescriptor<ClaudeProposal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        guard !proposals.isEmpty else { return Reply(ok: true, text: "No suggestions sent to Civa yet.") }
        let text = proposals.prefix(50).map { proposal in
            let status = switch proposal.status {
            case .pending: "waiting for the user"
            case .applied: "applied"
            case .dismissed: "dismissed"
            }
            let decided = proposal.decidedAt.map { " on \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
            return "[suggestion_id: \(proposal.id)] \(ClaudeDecisions.describe(proposal))\nSent \(proposal.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(status)\(decided)"
        }.joined(separator: "\n\n")
        return Reply(ok: true, text: text)
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
        return Reply(ok: true, text: "Sent to Civa (suggestion_id: \(proposal.id)). The user reviews it there; nothing changes until they apply it. list_suggestions shows whether they applied or dismissed it.")
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

        // Structure: records from the Career Profile, skills, removals, order, Master.
        let recordInputs = decode([RecordInput].self, arguments["add_records"]) ?? []
        var additions = profileEntries(recordInputs, context, permissions).map { ClaudeProposal.ResumeEdit.Addition(kind: $0.kind, entry: $0.entry) }
        let skillNames = Set((decode([String].self, arguments["add_skills"]) ?? []).map { $0.lowercased() })
        let skills = permissions.canRead(.skills) && !skillNames.isEmpty
            ? ((try? context.fetch(FetchDescriptor<Skill>())) ?? []).filter { !$0.needsReview && skillNames.contains($0.name.lowercased()) } : []
        additions += ResumeBuilder.skillLines(skills).map { .init(kind: .skills, entry: $0) }
        let removals = (decode([String].self, arguments["remove_entries"]) ?? []).compactMap(UUID.init(uuidString:)).filter(known.contains)
        let sectionOrder = decode([String].self, arguments["section_order"])
        let entryOrder = decode([String].self, arguments["entry_order"])?.compactMap(UUID.init(uuidString:))
        let makeMaster = arguments["make_master"] == "true" && !resume.isMaster ? true : nil

        let edit = ClaudeProposal.ResumeEdit(
            summary: summary, summaryOptions: summaryOptions, entries: entries,
            additions: additions.isEmpty ? nil : additions, removals: removals.isEmpty ? nil : removals,
            sectionOrder: sectionOrder?.isEmpty == false ? sectionOrder : nil, entryOrder: entryOrder?.isEmpty == false ? entryOrder : nil,
            makeMaster: makeMaster
        )
        guard summary != nil || summaryOptions != nil || !entries.isEmpty || edit.hasStructure else {
            return Reply(ok: false, text: "Nothing to suggest: send a summary, entries with entry ids from get_resume, add_records, add_skills, remove_entries, section_order, entry_order, or make_master.")
        }
        let proposal = ClaudeProposal(
            kind: .resumeEdit, targetID: resume.id, targetTitle: resume.displayTitle, category: .resumes,
            requestID: arguments["request_id"].flatMap(UUID.init(uuidString:)), note: arguments["note"] ?? "",
            payload: edit
        )
        var reply = propose(proposal, tool: tool, summary: String(localized: "Suggested changes to “\(resume.displayTitle)”"), context: context)
        let skipped = inputs.count - entries.count
        if skipped > 0 { reply.text += " \(skipped) entries were left out because their ids aren't in this resume." }
        let leftOut = recordInputs.count - (additions.count - ResumeBuilder.skillLines(skills).count)
        if leftOut > 0 { reply.text += " \(leftOut) record(s) left out of add_records: unconfirmed, not shared, or not found." }
        if skills.count < skillNames.count { reply.text += " \(skillNames.count - skills.count) skill(s) left out: unconfirmed, not shared, or not found." }
        return reply
    }

    // MARK: - Profile edits

    private static func recordEdit(_ arguments: [String: String], _ context: ModelContext, _ permissions: ClaudePermissions) -> Reply {
        let tool = "suggest_profile_edit"
        typealias Field = ClaudeProposal.RecordEdit.Field
        guard let field = arguments["field"].flatMap(Field.init(rawValue:)) else {
            return Reply(ok: false, text: "Send a field: \(Field.allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        let id = arguments["record_id"].flatMap(UUID.init(uuidString:))
        if arguments["record_id"]?.isBlank == false, id == nil {
            return Reply(ok: false, text: "record_id isn't an id. Use the id from the list tools, or leave it out for personal information.")
        }
        /// The record, by id; without an id, Personal Information.
        func find<M: ClaudeEditable>(_ type: M.Type) -> (id: UUID, title: String, category: ClaudeCategory, fields: Set<Field>)? {
            let records = (try? context.fetch(FetchDescriptor<M>())) ?? []
            let record = id.map { id in records.first { $0.id == id } } ?? (M.self == PersonalInfo.self ? records.first : nil)
            return record.map { ($0.id, $0.displayTitle, M.claudeCategory, M.editableFields) }
        }
        let target = find(PersonalInfo.self) ?? find(Experience.self) ?? find(Project.self) ?? find(Education.self)
            ?? find(Achievement.self) ?? find(Certification.self) ?? find(Skill.self)
        guard let target else {
            return Reply(ok: false, text: id == nil ? "There's no personal information in Civa yet." : "No profile record with that id. Use the ids from the list tools.")
        }
        guard permissions.canSuggest(target.category) else { return refuse(target.category, tool: tool, context) }
        guard target.fields.contains(field) else {
            return Reply(ok: false, text: "That record's \(field.rawValue) can't be suggested. Allowed: \(target.fields.map(\.rawValue).sorted().joined(separator: ", ")).")
        }
        let lines = decode([String].self, arguments["lines"])?.filter { !$0.isBlank }
        let text = arguments["text"]
        let versions: [ClaudeProposal.Version]?
        do {
            versions = try options(arguments, "options") { field.isLines ? $0.lines?.isEmpty == false : $0.text?.isBlank == false }
        } catch let error as OptionsError {
            return Reply(ok: false, text: error.message)
        } catch {
            return Reply(ok: false, text: error.localizedDescription)
        }
        guard versions != nil || (field.isLines ? lines?.isEmpty == false : text?.isBlank == false) else {
            return Reply(ok: false, text: field.isLines ? "Send the new \(field.rawValue) as lines, or options with lines." : "Send the new \(field.rawValue) as text, or options with text.")
        }
        let proposal = ClaudeProposal(
            kind: .recordEdit, targetID: target.id, targetTitle: target.title, category: target.category,
            requestID: arguments["request_id"].flatMap(UUID.init(uuidString:)), note: arguments["note"] ?? "",
            payload: ClaudeProposal.RecordEdit(
                field: field, text: versions != nil || field.isLines ? nil : text,
                lines: versions != nil || !field.isLines ? nil : lines, options: versions
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

    /// Confirmed records with these ids, from categories the user shares, as resume entries in
    /// the order given. Bullets Claude sent replace the record's own and mark the entry.
    private static func profileEntries(
        _ inputs: [RecordInput], _ context: ModelContext, _ permissions: ClaudePermissions
    ) -> [(kind: ResumeSection.Kind, entry: ResumeEntry)] {
        func fetch<M: ProfileRecord>(_ type: M.Type, _ category: ClaudeCategory) -> [any ProfileRecord] {
            guard permissions.canRead(category) else { return [] }
            return ((try? context.fetch(FetchDescriptor<M>())) ?? []).filter { !$0.needsReview }
        }
        let records = fetch(Experience.self, .experience) + fetch(Education.self, .education) + fetch(Project.self, .projects)
            + fetch(Achievement.self, .recognition) + fetch(Certification.self, .recognition)
        let byID = Dictionary(records.compactMap { record in ((record as? any DocumentOwner)?.id).map { ($0, record) } }, uniquingKeysWith: { first, _ in first })
        return inputs.compactMap { input in
            guard let id = UUID(uuidString: input.recordID), let record = byID[id], var entry = ResumeBuilder.entry(for: record) else { return nil }
            let kind: ResumeSection.Kind = switch record {
            case let experience as Experience: experience.kind == .professional ? .experience : .organizational
            case is Education: .education
            case is Project: .projects
            case is Achievement: .achievements
            default: .certifications
            }
            entry.sourceCopy = entry.asSourceCopy
            if let bullets = input.bullets?.filter({ !$0.isBlank }), !bullets.isEmpty {
                entry.bullets = bullets
                entry.claudeTouched = true
            }
            return (kind, entry)
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
        // Records in the order Claude sent them within each section, then the sections in its order.
        let order = inputs.compactMap { UUID(uuidString: $0.recordID) }
        let entryIDs = order.compactMap { id in document.sections.flatMap(\.entries).first { $0.sourceID == id }?.id }
        ClaudeDecisions.reorder(&document, sections: decode([String].self, arguments["section_order"]), entries: entryIDs)
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
        reply.text = "Drafted “\(title)” in Civa with \(found) records (resume_id: \(resume.id), suggestion_id: \(proposal.id)). It's waiting in Resumes for the user to keep or discard. To change it further, use suggest_resume_edit with its resume_id."
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
