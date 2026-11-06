//
//  SuggestedChangesTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct SuggestedChangesTests {
    private func setUp() -> (job: Experience, person: PersonalInfo, document: ResumeDocument) {
        let job = Experience(
            kind: .professional, organization: "Tokopedia", role: "iOS Engineer",
            start: YearMonth(year: 2024, month: 3), isCurrent: true, impacts: ["Cut drop-off by 18%"]
        )
        let person = PersonalInfo(fullName: "Alex Morgan", email: "alex@old.com")
        let document = ResumeBuilder.document(from: .init(personalInfo: person, experiences: [job]))
        return (job, person, document)
    }

    private func profile(_ person: PersonalInfo?, _ records: [any ImportableRecord]) -> ProfileSource {
        ProfileSource(person: person, records: records)
    }

    @Test func unchangedProfileHasNoSuggestions() {
        let (job, person, document) = setUp()
        #expect(document.headerSource != nil)
        #expect(document.sections[0].entries[0].sourceCopy != nil)
        #expect(SuggestedChanges.suggestions(for: document, from: profile(person, [job])).isEmpty)
    }

    @Test func suggestsOnlyWhatChangedInTheProfile() {
        var (job, person, document) = setUp()
        document.sections[0].entries[0].subtitle = "Tokopedia (Marketplace)"  // the user's own wording
        job.role = "Senior iOS Engineer"
        job.impacts.append("Mentored two engineers")
        person.email = "alex@example.com"

        let suggestions = SuggestedChanges.suggestions(for: document, from: profile(person, [job]))
        #expect(suggestions.map(\.target) == [.header, .entry(document.sections[0].entries[0].id)])
        #expect(suggestions[0].changes.map(\.new) == ["alex@example.com"])
        #expect(suggestions[1].changes.map(\.label) == ["Role", "Line added"])
        #expect(suggestions[1].changes.allSatisfy { !$0.replacesEdit })
    }

    @Test func applyingKeepsTheResumesOwnWording() {
        var (job, person, document) = setUp()
        document.sections[0].entries[0].subtitle = "Tokopedia (Marketplace)"
        job.role = "Senior iOS Engineer"
        job.impacts = ["Mentored two engineers"]  // one line replaced
        let source = profile(person, [job])

        for suggestion in SuggestedChanges.suggestions(for: document, from: source) {
            SuggestedChanges.apply(suggestion, to: &document, from: source)
        }
        let entry = document.sections[0].entries[0]
        #expect(entry.title == "Senior iOS Engineer")
        #expect(entry.subtitle == "Tokopedia (Marketplace)")
        #expect(entry.bullets == ["Mentored two engineers"])
        #expect(SuggestedChanges.suggestions(for: document, from: source).isEmpty)
    }

    @Test func flagsAnEditTheChangeWouldReplace() {
        var (job, person, document) = setUp()
        document.sections[0].entries[0].title = "Lead iOS Engineer"
        job.role = "Senior iOS Engineer"
        let change = SuggestedChanges.suggestions(for: document, from: profile(person, [job]))[0].changes[0]
        #expect(change.replacesEdit)
        #expect(change.old == "Lead iOS Engineer")
    }

    @Test func keepingTheResumeDismissesUntilTheNextChange() {
        var (job, person, document) = setUp()
        job.role = "Senior iOS Engineer"
        var source = profile(person, [job])
        let suggestion = SuggestedChanges.suggestions(for: document, from: source)[0]
        SuggestedChanges.dismiss(suggestion, in: &document, from: source)
        #expect(document.sections[0].entries[0].title == "iOS Engineer")
        #expect(SuggestedChanges.suggestions(for: document, from: source).isEmpty)

        job.role = "Staff iOS Engineer"
        source = profile(person, [job])
        #expect(SuggestedChanges.suggestions(for: document, from: source).count == 1)
    }

    @Test func unconfirmedChangesWaitAndDeletedRecordsAsk() {
        var (job, person, document) = setUp()
        job.role = "Senior iOS Engineer"
        job.status = .needsReview
        #expect(SuggestedChanges.suggestions(for: document, from: profile(person, [job])).isEmpty)

        let source = profile(person, [])  // the job was deleted
        let suggestion = SuggestedChanges.suggestions(for: document, from: source)[0]
        #expect(suggestion.target == .removedEntry(document.sections[0].entries[0].id))
        var kept = document
        SuggestedChanges.dismiss(suggestion, in: &kept, from: source)
        #expect(kept.sections[0].entries.count == 1)
        #expect(kept.sections[0].entries[0].sourceID == nil)
        SuggestedChanges.apply(suggestion, to: &document, from: source)
        #expect(document.sections[0].entries.isEmpty)
    }

    @Test func olderResumesStartTrackingFromNow() {
        var (job, person, document) = setUp()
        document.headerSource = nil
        document.sections[0].entries[0].sourceCopy = nil
        document.sections[0].entries[0].title = "My own title"
        let source = profile(person, [job])

        #expect(SuggestedChanges.startTracking(&document, from: source))
        #expect(SuggestedChanges.suggestions(for: document, from: source).isEmpty)
        #expect(!SuggestedChanges.startTracking(&document, from: source))

        job.role = "Senior iOS Engineer"
        #expect(SuggestedChanges.suggestions(for: document, from: profile(person, [job])).count == 1)
    }
}
