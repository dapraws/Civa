//
//  ClaudeToolsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct ClaudeToolsTests {
    private let container: ModelContainer
    private let permissions: ClaudePermissions

    init() throws {
        container = try ModelContainer.civa(inMemory: true)
        let defaults = try #require(UserDefaults(suiteName: "ClaudeToolsTests-\(UUID())"))
        permissions = ClaudePermissions(defaults: defaults)
        let context = container.mainContext
        context.insert(Experience(kind: .professional, organization: "Gojek", role: "iOS Engineer", impacts: ["Cut drop-off by 14%"]))
        context.insert(Experience(kind: .professional, organization: "Unverified Co", role: "Imported Role", status: .needsReview))
        context.insert(Resume(title: "Master Resume", targetPosition: "iOS Engineer"))
        try context.save()
    }

    private func call(_ tool: String, _ arguments: [String: String] = [:]) -> ClaudeLink.Reply {
        ClaudeTools.answer(ClaudeLink.Request(tool: tool, arguments: arguments), container: container, permissions: permissions)
    }

    private func log() throws -> [ClaudeActivity] {
        try ModelContext(container).fetch(FetchDescriptor<ClaudeActivity>())
    }

    @Test func refusesAndLogsWhenACategoryIsntShared() throws {
        let reply = call("list_experience")
        #expect(!reply.ok)
        #expect(!reply.text.contains("Gojek"))
        #expect(try log().map(\.kind) == [.denied])
    }

    @Test func sharesOnlyConfirmedRecordsAndLogsTheRead() throws {
        permissions.read.insert(.experience)
        let reply = call("list_experience")
        #expect(reply.ok)
        #expect(reply.text.contains("iOS Engineer — Gojek"))
        #expect(reply.text.contains("Cut drop-off by 14%"))
        #expect(!reply.text.contains("Imported Role"))
        #expect(reply.text.contains("1 more awaiting"))
        let entry = try #require(try log().first)
        #expect(entry.kind == .read)
        #expect(entry.category == .experience)
        #expect(entry.detail == "iOS Engineer")
    }

    @Test func statusNamesWhatIsShared() {
        #expect(call("check_connection").text.contains("hasn't shared any categories"))
        permissions.read = [.education, .skills]
        let text = call("check_connection").text
        #expect(text.contains("Education") && text.contains("Skills") && !text.contains("Experience"))
    }

    @Test func resumesAreFoundByID() throws {
        permissions.read.insert(.resumes)
        let list = call("list_resumes").text
        let id = try #require(list.firstMatch(of: /resume_id: ([0-9A-F-]+)/)?.1)
        #expect(call("get_resume", ["resume_id": String(id)]).text.contains("Master Resume"))
        #expect(!call("get_resume", ["resume_id": "nope"]).ok)
    }

    @Test func everyToolHasAnAnswer() {
        permissions.read = Set(ClaudeCategory.allCases)
        for tool in ClaudeLink.tools where tool.required.isEmpty {
            #expect(call(tool.name).ok, "\(tool.name)")
        }
    }
}
