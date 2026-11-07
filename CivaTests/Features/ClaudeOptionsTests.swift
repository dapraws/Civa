//
//  ClaudeOptionsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

/// Claude offers 2–3 labeled versions per change; the user picks one or keeps theirs.
@MainActor
struct ClaudeOptionsTests {
    private let container: ModelContainer
    private let permissions: ClaudePermissions
    private let gojek = Experience(kind: .professional, organization: "Gojek", role: "iOS Engineer", impacts: ["Rebuilt checkout"])
    private let resume: Resume

    init() throws {
        container = try ModelContainer.civa(inMemory: true)
        permissions = ClaudePermissions(defaults: try #require(UserDefaults(suiteName: "ClaudeOptionsTests-\(UUID())")))
        permissions.suggest = [.resumes, .experience]
        permissions.read = [.resumes, .experience]
        resume = Resume(title: "Master Resume", document: ResumeBuilder.document(from: .init(experiences: [gojek])))
        container.mainContext.insert(gojek)
        container.mainContext.insert(resume)
        try container.mainContext.save()
    }

    private var entryID: UUID { resume.document.sections.flatMap(\.entries)[0].id }

    private func call(_ tool: String, _ arguments: [String: String]) -> ClaudeLink.Reply {
        ClaudeTools.answer(.init(tool: tool, arguments: arguments), container: container, permissions: permissions)
    }

    private func proposal() throws -> ClaudeProposal {
        try #require(try ModelContext(container).fetch(FetchDescriptor<ClaudeProposal>()).first)
    }

    private let twoSummaries = #"[{"label":"Concise","text":"iOS engineer."},{"label":"With Numbers","text":"iOS engineer, 2M users."}]"#

    @Test func resumeEditAcceptsOptions() throws {
        let entries = #"[{"entry_id":"\#(entryID)","options":[{"label":"Concise","bullets":["Rebuilt checkout"]},{"label":"Job Keywords","bullets":["Rebuilt SwiftUI checkout"]}]}]"#
        let reply = call("suggest_resume_edit", ["resume_id": resume.id.uuidString, "note": "x", "summary_options": twoSummaries, "entries": entries])
        #expect(reply.ok, "\(reply.text)")
        let edit = try #require(try proposal().decode(ClaudeProposal.ResumeEdit.self))
        #expect(edit.summaryVersions.map(\.label) == ["Concise", "With Numbers"])
        #expect(edit.entries[0].versions.map(\.label) == ["Concise", "Job Keywords"])
        #expect(edit.hasOptions)
    }

    @Test func optionsMustBeTwoOrThreeWithLabels() {
        let one = #"[{"label":"Concise","text":"iOS engineer."}]"#
        let four = #"[{"label":"A","text":"a"},{"label":"B","text":"b"},{"label":"C","text":"c"},{"label":"D","text":"d"}]"#
        let unlabeled = #"[{"label":" ","text":"a"},{"label":"B","text":"b"}]"#
        for options in [one, four, unlabeled] {
            #expect(!call("suggest_resume_edit", ["resume_id": resume.id.uuidString, "note": "x", "summary_options": options]).ok)
        }
    }

    @Test func profileEditAcceptsOptions() throws {
        let options = #"[{"label":"Concise","lines":["Rebuilt checkout"]},{"label":"With Numbers","lines":["Rebuilt checkout for 2M users"]}]"#
        let reply = call("suggest_profile_edit", ["record_id": gojek.id.uuidString, "field": "impacts", "note": "x", "options": options])
        #expect(reply.ok, "\(reply.text)")
        let edit = try #require(try proposal().decode(ClaudeProposal.RecordEdit.self))
        #expect(edit.versions.count == 2)
        #expect(edit.resolved(1).lines == ["Rebuilt checkout for 2M users"])
    }

    @Test func picksResolveToTheChosenVersion() {
        let id = UUID()
        let skipped = UUID()
        let edit = ClaudeProposal.ResumeEdit(
            summaryOptions: [.init(label: "A", text: "First"), .init(label: "B", text: "Second")],
            entries: [
                .init(entryID: id, options: [.init(label: "A", lines: ["One"]), .init(label: "B", lines: ["Two"])]),
                .init(entryID: skipped, options: [.init(label: "A", lines: ["Three"]), .init(label: "B", lines: ["Four"])]),
            ]
        )
        let resolved = edit.resolved([.summary: 1, .entry(id): 0])
        #expect(resolved.summary == "Second")
        #expect(resolved.entries.map(\.entryID) == [id])
        #expect(resolved.entries[0].bullets == ["One"])
    }

    @Test func singleVersionAppliesWithoutAPick() {
        let id = UUID()
        let edit = ClaudeProposal.ResumeEdit(summary: "Only", entries: [.init(entryID: id, bullets: ["Only bullet"])])
        #expect(!edit.hasOptions)
        let resolved = edit.resolved([:])
        #expect(resolved.summary == "Only")
        #expect(resolved.entries[0].bullets == ["Only bullet"])
    }
}
