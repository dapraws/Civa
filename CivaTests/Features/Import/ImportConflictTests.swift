//
//  ImportConflictTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct ImportConflictTests {
    private func job() -> Experience {
        Experience(
            kind: .professional, organization: "Tokopedia", role: "iOS Engineer",
            start: YearMonth(year: 2024, month: 3), isCurrent: true, impacts: ["Cut drop-off by 18%"]
        )
    }

    private func incoming() -> ImportItem {
        ImportItem(
            category: .experience, title: "iOS Engineer", subtitle: "PT Tokopedia Tbk.", location: "Jakarta",
            start: YearMonth(year: 2024, month: 2), isCurrent: true, bullets: ["Cut drop-off by 18%", "Shipped sync"]
        )
    }

    @Test func companySuffixesAndPunctuationDontMatter() {
        #expect(ImportMatcher.normalize("PT. Tokopedia Tbk") == "tokopedia")
        #expect(ImportMatcher.normalize("Acme, Inc.") == "acme")
    }

    @Test func sameCompanyMatchesByRoleOrOverlappingDates() {
        let existing = job().importItem
        #expect(ImportMatcher.isMatch(incoming(), existing))

        var promoted = incoming()
        promoted.title = "Senior iOS Engineer"  // different role, overlapping dates
        #expect(ImportMatcher.isMatch(promoted, existing))

        var earlier = promoted
        earlier.start = YearMonth(year: 2020)
        earlier.end = YearMonth(year: 2021)
        earlier.isCurrent = false
        #expect(!ImportMatcher.isMatch(earlier, existing))

        var elsewhere = incoming()
        elsewhere.subtitle = "Gojek"
        #expect(!ImportMatcher.isMatch(elsewhere, existing))
    }

    @Test func matchWithDifferencesStartsAsMergeThatFillsOnlyEmptyFields() {
        let record = job()
        var draft = ImportDraft(items: [incoming()])
        draft.match(against: [record.importItem])
        let item = draft.items[0]
        #expect(item.action == .merge)
        #expect(item.matchID == record.id)
        #expect(Set(ImportMatcher.differences(item, record.importItem)) == [.location, .start])  // company equal once normalized
        #expect(item.picks == [.location])  // the profile had no location; its start date stays
    }

    @Test func identicalMatchStartsSkipped() {
        let record = job()
        var draft = ImportDraft(items: [record.importItem])
        draft.items[0].id = UUID()
        draft.match(against: [record.importItem])
        #expect(draft.items[0].isIdentical)
        #expect(draft.items[0].action == .skip)
    }

    @Test func mergeKeepsUnpickedValuesAddsLinesAndAsksForReview() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let record = job()
        record.sources = [.manual()]
        context.insert(record)

        var draft = ImportDraft(items: [incoming()])
        draft.match(against: [record.importItem])
        draft.add(to: context, existing: nil, records: [record.id: record], source: RecordSource(name: "cv.pdf", date: .now))
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Experience>()) == 1)
        #expect(record.location == "Jakarta")
        #expect(record.start == YearMonth(year: 2024, month: 3))
        #expect(record.organization == "Tokopedia")
        #expect(record.impacts == ["Cut drop-off by 18%", "Shipped sync"])
        #expect(record.needsReview)
        #expect(record.sources.map(\.name) == ["", "cv.pdf"])
    }

    @Test func addingSeparatelyFlagsAPossibleDuplicate() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let record = job()
        context.insert(record)

        var draft = ImportDraft(items: [incoming()])
        draft.match(against: [record.importItem])
        draft.items[0].action = .add
        draft.add(to: context, existing: nil, records: [record.id: record], source: RecordSource(name: "cv.pdf", date: .now))
        try context.save()

        let added = try context.fetch(FetchDescriptor<Experience>()).first { $0.id != record.id }
        #expect(added?.possibleDuplicateOf == record.id)
        #expect(added?.needsReview == true)
    }

    @Test func newRecordsGetAManualSourceOnFirstSave() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let editor = RecordEditor(creating: Skill(name: "Swift"), in: container.mainContext)
        #expect(editor.save())
        #expect(editor.record.sources.map(\.name) == [""])
    }
}
