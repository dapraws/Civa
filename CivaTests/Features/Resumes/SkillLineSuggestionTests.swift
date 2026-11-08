//
//  SkillLineSuggestionTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct SkillLineSuggestionTests {
    private let swift = Skill(name: "Swift", category: "Languages")
    private let kotlin = Skill(name: "Kotlin", category: "Languages")
    private let figma = Skill(name: "Figma", category: "Tools")

    private func resume() -> ResumeDocument {
        ResumeBuilder.document(from: .init(skills: [swift, kotlin, figma]))
    }

    private func line(_ document: ResumeDocument, _ category: String) -> ResumeEntry? {
        document.sections.first { $0.kind == .skills }?.entries.first { $0.title == category }
    }

    private func source(_ skills: [Skill]) -> ProfileSource {
        ProfileSource(person: nil, records: skills)
    }

    @Test func noSuggestionWhileSkillsAreUnchanged() {
        #expect(SuggestedChanges.suggestions(for: resume(), from: source([swift, kotlin, figma])).isEmpty)
    }

    @Test func addRemoveAndRenameAreSuggestedAndApplied() throws {
        var document = resume()
        let python = Skill(name: "Python", category: "Languages")
        swift.name = "Swift 6"
        let profile = source([swift, python, figma])  // Kotlin deleted

        let suggestion = try #require(SuggestedChanges.suggestions(for: document, from: profile).first)
        let labels = suggestion.changes.map(\.label)
        #expect(labels.contains("Skill added") && labels.contains("Skill removed") && labels.contains("Skill renamed"))

        SuggestedChanges.apply(suggestion, to: &document, from: profile)
        #expect(line(document, "Languages")?.subtitle == "Swift 6, Python")
        #expect(SuggestedChanges.suggestions(for: document, from: profile).isEmpty)
    }

    @Test func keepsTheUsersOwnOrderAndRemovals() throws {
        var document = resume()
        let index = try #require(document.sections.firstIndex { $0.kind == .skills })
        let entry = try #require(document.sections[index].entries.firstIndex { $0.title == "Languages" })
        document.sections[index].entries[entry].subtitle = "Swift"  // the user dropped Kotlin from this resume

        let go = Skill(name: "Go", category: "Languages")
        let profile = source([swift, kotlin, go, figma])
        let suggestion = try #require(SuggestedChanges.suggestions(for: document, from: profile).first)
        #expect(suggestion.changes.map(\.new) == ["Go"])  // Kotlin isn't suggested back
        SuggestedChanges.apply(suggestion, to: &document, from: profile)
        #expect(line(document, "Languages")?.subtitle == "Swift, Go")
    }

    @Test func dismissingWaitsForTheNextChange() throws {
        var document = resume()
        let profile = source([swift, kotlin, figma, Skill(name: "Rust", category: "Languages")])
        let suggestion = try #require(SuggestedChanges.suggestions(for: document, from: profile).first)
        SuggestedChanges.dismiss(suggestion, in: &document, from: profile)
        #expect(SuggestedChanges.suggestions(for: document, from: profile).isEmpty)
        #expect(line(document, "Languages")?.subtitle == "Kotlin, Swift")
    }

    @Test func olderSkillLinesStartTracking() {
        var document = resume()
        for s in document.sections.indices {
            for e in document.sections[s].entries.indices { document.sections[s].entries[e].sourceCopy = nil }
        }
        #expect(SuggestedChanges.startTracking(&document, from: source([swift, kotlin, figma])))
        #expect(line(document, "Tools")?.sourceCopy?.skills?.count == 1)
    }

    @Test func applicationsHoldDocumentsAndKeepThemWhenDeleted() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let application = JobApplication(company: "Grab", position: "iOS Engineer")
        context.insert(application)
        let files = ["Grab offer.pdf", "Cover letter.pdf", "Posting.pdf"].map {
            DocumentFiles.Loaded(url: URL(filePath: "/tmp/\($0)"), data: Data([1]))
        }
        let documents = DocumentFiles.insert(files, linkedTo: application, in: context)
        try context.save()
        #expect(documents.map(\.kind) == [.offerLetter, .coverLetter, .jobPosting])
        #expect(application.documents.count == 3)
        #expect(documents[0].linkedRecords.map(\.id) == [application.id])

        context.delete(application)
        try context.save()
        let kept = try context.fetch(FetchDescriptor<SupportingDocument>())
        #expect(kept.count == 3)
        #expect(kept.allSatisfy { $0.applications.isEmpty })
    }
}
