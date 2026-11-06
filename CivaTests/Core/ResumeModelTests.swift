//
//  ResumeModelTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct ResumeModelTests {
    @Test func documentSurvivesSaveAndFetch() throws {
        let container = try ModelContainer.civa(inMemory: true)
        var document = ResumeDocument.blank
        document.header.fullName = "Alex Morgan"
        document.summary = "iOS engineer."
        document.sections[0].entries = [ResumeEntry(title: "iOS Engineer", bullets: ["Shipped onboarding"])]
        document.format.paper = .letter
        container.mainContext.insert(Resume(title: "iOS Resume", document: document))
        try container.mainContext.save()

        let stored = try ModelContext(container).fetch(FetchDescriptor<Resume>())
        #expect(stored.first?.document == document)
    }

    @Test func blankResumeHasTheUsualSections() {
        #expect(ResumeDocument.blank.sections.map(\.kind) == [.experience, .education, .projects, .skills])
    }

    @Test func needsAName() {
        #expect(Resume(title: " ").validationErrors()[\Resume.title] != nil)
        #expect(Resume(title: "iOS Resume").validationErrors().isEmpty)
    }
}
