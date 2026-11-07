//
//  ClaudeVisibilityTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct ClaudeVisibilityTests {
    private var document: ResumeDocument {
        var document = ResumeDocument.blank
        document.sections[0].entries = [ResumeEntry(title: "iOS Engineer", bullets: ["Built checkout"])]
        return document
    }

    @Test func applyMarksClaudeText() throws {
        var document = document
        let id = document.sections[0].entries[0].id
        let edit = ClaudeProposal.ResumeEdit(summary: "New summary", entries: [.init(entryID: id, title: nil, subtitle: nil, bullets: ["Rebuilt checkout"])])
        ClaudeDecisions.apply(edit, to: &document)
        #expect(document.claudeTouchedSummary == true)
        #expect(document.sections[0].entries[0].claudeTouched == true)
    }

    @Test func manualEditClearsClaudeTag() {
        var document = document
        document.sections[0].entries[0].claudeTouched = true
        document.claudeTouchedSummary = true
        var entry = document.sections[0].entries[0]
        entry.bullets = ["Rebuilt checkout, by hand"]
        document.updateEntry(entry.id, to: entry)
        document.setSummary("Mine")
        #expect(document.sections[0].entries[0].claudeTouched == nil)
        #expect(document.claudeTouchedSummary == nil)
        #expect(document.summary == "Mine")
    }

    @Test func sameValueKeepsClaudeTag() {
        var document = document
        document.sections[0].entries[0].claudeTouched = true
        document.summary = "Same"
        document.claudeTouchedSummary = true
        document.updateEntry(document.sections[0].entries[0].id, to: document.sections[0].entries[0])
        document.setSummary("Same")
        #expect(document.sections[0].entries[0].claudeTouched == true)
        #expect(document.claudeTouchedSummary == true)
    }

    @Test func aiActivityShowsOnlyWhenEnabled() {
        #expect(!AppSection.visible(claudeEnabled: false).contains(.aiActivity))
        let sections = AppSection.visible(claudeEnabled: true)
        #expect(sections.firstIndex(of: .aiActivity) == sections.firstIndex(of: .applications).map { $0 + 1 })
        #expect(sections.last == .settings)
    }
}
