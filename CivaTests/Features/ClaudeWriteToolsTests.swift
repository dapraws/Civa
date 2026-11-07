//
//  ClaudeWriteToolsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct ClaudeWriteToolsTests {
    private let container: ModelContainer
    private let permissions: ClaudePermissions
    private let gojek = Experience(kind: .professional, organization: "Gojek", role: "iOS Engineer", impacts: ["Rebuilt checkout"])
    private let unconfirmed = Experience(kind: .professional, organization: "Imported", role: "Unconfirmed", status: .needsReview)
    private let resume: Resume

    init() throws {
        container = try ModelContainer.civa(inMemory: true)
        permissions = ClaudePermissions(defaults: try #require(UserDefaults(suiteName: "ClaudeWriteToolsTests-\(UUID())")))
        resume = Resume(title: "Master Resume", document: ResumeBuilder.document(from: .init(experiences: [gojek])))
        resume.isMaster = true
        var document = resume.document
        document.format.font = .georgia
        resume.document = document
        let context = container.mainContext
        [gojek, unconfirmed].forEach { context.insert($0) }
        context.insert(resume)
        try context.save()
    }

    private func call(_ tool: String, _ arguments: [String: String]) -> ClaudeLink.Reply {
        ClaudeTools.answer(.init(tool: tool, arguments: arguments), container: container, permissions: permissions)
    }

    private func fetch<M: PersistentModel>(_ type: M.Type) throws -> [M] {
        try ModelContext(container).fetch(FetchDescriptor<M>())
    }

    private var entryID: UUID { resume.document.sections[0].entries[0].id }

    @Test func refusesWithoutSuggestPermission() throws {
        permissions.read = [.resumes]
        let reply = call("suggest_resume_edit", ["resume_id": resume.id.uuidString, "summary": "New", "note": "x"])
        #expect(!reply.ok)
        #expect(try fetch(ClaudeProposal.self).isEmpty)
        #expect(try fetch(ClaudeActivity.self).map(\.kind) == [.denied])
    }

    @Test func resumeEditIsStoredNotApplied() throws {
        permissions.suggest = [.resumes]
        let request = ClaudeRequest(kind: .writeSummary, targetID: resume.id, targetTitle: "Master Resume")
        container.mainContext.insert(request)
        try container.mainContext.save()

        let entries = #"[{"entry_id":"\#(entryID)","bullets":["Led the SwiftUI rebuild of checkout"]},{"entry_id":"\#(UUID())","bullets":["ghost"]}]"#
        let reply = call("suggest_resume_edit", [
            "resume_id": resume.id.uuidString, "request_id": request.id.uuidString,
            "summary": "iOS engineer.", "entries": entries, "note": "Tightened wording",
        ])
        #expect(reply.ok)
        #expect(reply.text.contains("1 entries were left out"))
        #expect(resume.document.summary.isEmpty)  // nothing changed yet

        let proposal = try #require(try fetch(ClaudeProposal.self).first)
        let edit = try #require(proposal.decode(ClaudeProposal.ResumeEdit.self))
        #expect(edit.entries.count == 1)
        #expect(try fetch(ClaudeRequest.self).first?.status == .answered)

        var document = resume.document
        ClaudeDecisions.apply(edit, to: &document)
        #expect(document.summary == "iOS engineer.")
        #expect(document.sections[0].entries[0].bullets == ["Led the SwiftUI rebuild of checkout"])

        ClaudeDecisions.record(proposal.id, .applied, container: container)
        #expect(try fetch(ClaudeProposal.self).first?.status == .applied)
        #expect(try fetch(ClaudeActivity.self).contains { $0.kind == .approved })
    }

    @Test func profileEditsOnlyTouchAllowedFields() throws {
        permissions.suggest = [.experience]
        #expect(!call("suggest_profile_edit", ["record_id": gojek.id.uuidString, "field": "headline", "text": "x", "note": "x"]).ok)
        #expect(call("suggest_profile_edit", ["record_id": gojek.id.uuidString, "field": "impacts", "lines": #"["Cut drop-off 14%"]"#, "note": "x"]).ok)
        let edit = try #require(try fetch(ClaudeProposal.self).first?.decode(ClaudeProposal.RecordEdit.self))
        gojek.apply(edit)
        #expect(gojek.impacts == ["Cut drop-off 14%"])
    }

    @Test func draftUsesConfirmedSharedRecordsAndTheMastersLayout() throws {
        permissions.suggest = [.resumes]
        permissions.read = [.experience]
        let records = #"[{"record_id":"\#(gojek.id)","bullets":["Shipped GoPay checkout in SwiftUI"]},{"record_id":"\#(unconfirmed.id)"}]"#
        let reply = call("create_resume_draft", ["title": "Grab Draft", "records": records, "summary": "Payments iOS engineer.", "note": "For Grab"])
        #expect(reply.ok)
        #expect(reply.text.contains("1 ids were left out"))
        let draft = try #require(try fetch(Resume.self).first { $0.title == "Grab Draft" })
        #expect(draft.isClaudeDraft)
        #expect(draft.document.summary == "Payments iOS engineer.")
        #expect(draft.document.format.font == .georgia)
        let entries = draft.document.sections.flatMap(\.entries)
        #expect(entries.map(\.title) == ["iOS Engineer"])
        #expect(entries[0].bullets == ["Shipped GoPay checkout in SwiftUI"])
        #expect(try fetch(ClaudeProposal.self).first?.kind == .resumeDraft)
    }

    @Test func importRecordsGoToReview() throws {
        permissions.suggest = [.experience]
        let records = #"[{"category":"experience","title":"Software Engineer","subtitle":"Pertamina","start":"2024-03","current":true,"bullets":["Built a portal"]},{"category":"spaceship","title":"x"}]"#
        #expect(call("suggest_profile_records", ["source": "CV.pdf", "records": records, "note": "From your CV"]).ok)
        let payload = try #require(try fetch(ClaudeProposal.self).first?.decode(ClaudeProposal.ProfileImport.self))
        let draft = ClaudeDecisions.draft(from: payload)
        #expect(draft.items.count == 1)
        #expect(draft.items[0].start == YearMonth(year: 2024, month: 3))
        #expect(draft.items[0].isCurrent)

        permissions.suggest = []
        #expect(!call("suggest_profile_records", ["source": "CV.pdf", "records": records, "note": "x"]).ok)
    }

    @Test func pendingRequestsDescribeTheTask() throws {
        let request = ClaudeRequest(kind: .improveBullets, targetID: gojek.id, targetTitle: "iOS Engineer")
        container.mainContext.insert(request)
        try container.mainContext.save()
        let text = call("get_pending_requests", [:]).text
        #expect(text.contains(request.id.uuidString))
        #expect(text.contains("suggest_profile_edit"))
        #expect(call("finish_request", ["request_id": request.id.uuidString, "note": "Experience isn't shared", "failed": "true"]).ok)
        #expect(try fetch(ClaudeRequest.self).first?.status == .failed)
        #expect(call("get_pending_requests", [:]).text.contains("No pending requests"))
    }

    @Test func askNeedsAConnectionAndPermission() {
        let ask = ClaudeAsk.Ask(kind: .writeSummary, category: .resumes, targetID: resume.id, targetTitle: "Master")
        if !ClaudeBridge.shared.isEnabled {
            #expect(ClaudeAsk.send(ask, container: container, permissions: permissions).id == "notConnected")
        }
    }
}
