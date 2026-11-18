//
//  ClaudeAccessTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

/// Claude's wider access in 1.1: every field, resume structure, suggestion status, and records
/// awaiting review by name. Everything still waits for the user in Civa.
@MainActor
struct ClaudeAccessTests {
    private let container: ModelContainer
    private let permissions: ClaudePermissions
    private let person = PersonalInfo(fullName: "Garuda Arrasyid", headline: "Biologist")
    private let lab = Experience(kind: .professional, organization: "UNJ", role: "Lab Assistant", impacts: ["Guided 40 students"])
    private let thesis = Project(name: "EPS Production", role: "Undergraduate Thesis", impacts: ["Tested 4 nitrogen sources"])
    private let school = Education(institution: "Universitas Negeri Jakarta", degree: "Bachelor of Science")
    private let swift = Skill(name: "Plate Count", category: "Laboratory")
    private let pendingSkill = Skill(name: "PCR", category: "Laboratory", status: .needsReview)
    private let pendingJob = Experience(kind: .professional, organization: "Imported Co", role: "QC Intern", status: .needsReview)
    private let resume: Resume

    init() throws {
        container = try ModelContainer.civa(inMemory: true)
        permissions = ClaudePermissions(defaults: try #require(UserDefaults(suiteName: "ClaudeAccessTests-\(UUID())")))
        resume = Resume(title: "Tailored", document: ResumeBuilder.document(from: .init(experiences: [lab], education: [school])))
        let context = container.mainContext
        context.insert(person); context.insert(lab); context.insert(thesis); context.insert(school)
        context.insert(swift); context.insert(pendingSkill); context.insert(pendingJob)
        context.insert(resume)
        try context.save()
    }

    private func call(_ tool: String, _ arguments: [String: String] = [:]) -> ClaudeLink.Reply {
        ClaudeTools.answer(.init(tool: tool, arguments: arguments), container: container, permissions: permissions)
    }

    private func proposals() throws -> [ClaudeProposal] {
        try ModelContext(container).fetch(FetchDescriptor<ClaudeProposal>())
    }

    // MARK: - Personal information (feedback 1)

    @Test func personalInfoNeedsNoID() throws {
        permissions.read = [.personal]
        permissions.suggest = [.personal]
        #expect(call("get_personal_info").text.contains("id: \(person.id)"))
        let reply = call("suggest_profile_edit", ["field": "headline", "text": "QC Microbiology Graduate", "note": "Fits QC roles"])
        #expect(reply.ok, "\(reply.text)")
        #expect(try proposals().first?.targetID == person.id)
    }

    // MARK: - Any field (feedback 7)

    @Test func anyTextFieldCanBeSuggested() throws {
        permissions.suggest = [.experience, .education, .skills]
        #expect(call("suggest_profile_edit", ["record_id": lab.id.uuidString, "field": "role", "text": "Laboratory Assistant", "note": "x"]).ok)
        #expect(call("suggest_profile_edit", ["record_id": school.id.uuidString, "field": "thesis", "text": "EPS by L. pentosus FT3", "note": "x"]).ok)
        #expect(call("suggest_profile_edit", ["record_id": swift.id.uuidString, "field": "name", "text": "Total Plate Count", "note": "x"]).ok)
        #expect(!call("suggest_profile_edit", ["record_id": lab.id.uuidString, "field": "thesis", "text": "x", "note": "x"]).ok)

        let edit = ClaudeProposal.RecordEdit(field: .thesis, text: "EPS by L. pentosus FT3")
        school.apply(edit)
        #expect(school.thesis == "EPS by L. pentosus FT3")
        swift.apply(ClaudeProposal.RecordEdit(field: .name, text: "Total Plate Count"))
        #expect(swift.name == "Total Plate Count")
    }

    // MARK: - Resume structure (feedback 2, 3, 11)

    @Test func resumeEditsAddRemoveAndOrder() throws {
        permissions.read = [.projects, .skills]
        permissions.suggest = [.resumes]
        let labEntry = try #require(resume.document.sections.first { $0.kind == .experience }?.entries.first)
        let reply = call("suggest_resume_edit", [
            "resume_id": resume.id.uuidString, "note": "Thesis first for QC roles",
            "add_records": #"[{"record_id":"\#(thesis.id)","bullets":["Tested 4 nitrogen sources at 3 levels"]},{"record_id":"\#(pendingJob.id)"}]"#,
            "add_skills": #"["Plate Count","PCR"]"#,
            "remove_entries": #"["\#(labEntry.id)"]"#,
            "section_order": #"["projects","education"]"#,
        ])
        #expect(reply.ok, "\(reply.text)")
        #expect(reply.text.contains("suggestion_id"))
        #expect(reply.text.contains("1 record"), "the unconfirmed record is reported as left out: \(reply.text)")

        let edit = try #require(try proposals().first?.decode(ClaudeProposal.ResumeEdit.self))
        var document = resume.document
        ClaudeDecisions.apply(edit.resolved([:]), to: &document)
        #expect(document.sections.map(\.kind).prefix(2) == [.projects, .education])
        #expect(!document.sections.flatMap(\.entries).contains { $0.id == labEntry.id })
        let project = try #require(document.sections.first { $0.kind == .projects }?.entries.first)
        #expect(project.sourceID == thesis.id)
        #expect(project.bullets == ["Tested 4 nitrogen sources at 3 levels"])
        let skills = try #require(document.sections.first { $0.kind == .skills }?.entries.first)
        #expect(skills.subtitle == "Plate Count")
    }

    @Test func masterResumeCanBeSuggested() throws {
        permissions.suggest = [.resumes]
        #expect(call("suggest_resume_edit", ["resume_id": resume.id.uuidString, "make_master": "true", "note": "Use this one"]).ok)
        let edit = try #require(try proposals().first?.decode(ClaudeProposal.ResumeEdit.self))
        let context = container.mainContext
        try ClaudeDecisions.apply(edit.resolved([:]), to: resume, in: context)
        #expect(resume.isMaster)
    }

    @Test func draftsFollowTheGivenOrder() throws {
        permissions.read = [.experience, .projects, .education]
        permissions.suggest = [.resumes]
        let records = #"[{"record_id":"\#(thesis.id)"},{"record_id":"\#(lab.id)"},{"record_id":"\#(school.id)"}]"#
        #expect(call("create_resume_draft", ["title": "QC Micro", "records": records, "section_order": #"["projects","education","experience"]"#, "note": "x"]).ok)
        let draft = try #require(try ModelContext(container).fetch(FetchDescriptor<Resume>()).first { $0.title == "QC Micro" })
        #expect(draft.document.sections.map(\.kind) == [.projects, .education, .experience])
    }

    // MARK: - Pending records (feedback 4)

    @Test func recordsAwaitingReviewAreNamed() {
        permissions.read = [.experience, .skills]
        let jobs = call("list_experience").text
        #expect(jobs.contains("QC Intern"))
        #expect(!jobs.contains("Imported Co"), "only the title, not the details")
        #expect(call("list_skills").text.contains("PCR"))
    }

    // MARK: - Suggestion status (feedback 5)

    @Test func suggestionsReportTheirStatus() throws {
        permissions.read = [.resumes]
        permissions.suggest = [.resumes]
        #expect(call("suggest_resume_edit", ["resume_id": resume.id.uuidString, "summary": "QC-focused biologist.", "note": "x"]).ok)
        let proposal = try #require(try proposals().first)
        #expect(call("list_suggestions").text.contains("waiting"))
        ClaudeDecisions.record(proposal.id, .applied, container: container)
        let list = call("list_suggestions").text
        #expect(list.contains("applied"))
        #expect(list.contains(proposal.id.uuidString))
    }

    // MARK: - Category fields (feedback 6)

    @Test func importedRecordsKeepCategoryFields() throws {
        let payload = ClaudeProposal.ProfileImport(source: "CV", records: [
            .init(category: "certifications", title: "TOEFL ITP", issuer: "ETS", issued: "2025-08", score: "573", credentialURL: "https://ets.org/x"),
            .init(category: "education", title: "Bachelor of Science", subtitle: "Universitas Negeri Jakarta", fieldOfStudy: "Biology", grade: "3.30 / 4.00"),
            .init(category: "projects", title: "EPS Production", role: "Undergraduate Thesis", url: "https://repo.unj.ac.id/x"),
        ])
        let records = ClaudeDecisions.draft(from: payload).items.map { $0.record(source: RecordSource(name: "CV", date: .now)) }
        let toefl = try #require(records.compactMap { $0 as? Certification }.first)
        #expect(toefl.issuer == "ETS")
        #expect(toefl.credentialURL == "https://ets.org/x")
        #expect(toefl.customFields.contains { $0.name == "Score" && $0.value == "573" })
        let education = try #require(records.compactMap { $0 as? Education }.first)
        #expect(education.fieldOfStudy == "Biology")
        #expect(education.gradeValue == 3.3)
        let project = try #require(records.compactMap { $0 as? Project }.first)
        #expect(project.role == "Undergraduate Thesis")
        #expect(project.url == "https://repo.unj.ac.id/x")
    }

    // MARK: - One record

    @Test func oneRecordByID() {
        permissions.read = [.education]
        #expect(call("get_profile_record", ["record_id": school.id.uuidString]).text.contains("Universitas Negeri Jakarta"))
        #expect(!call("get_profile_record", ["record_id": lab.id.uuidString]).ok, "experience isn't shared")
    }
}
