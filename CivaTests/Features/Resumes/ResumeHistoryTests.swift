//
//  ResumeHistoryTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import Testing
@testable import Civa

@MainActor
struct ResumeHistoryTests {
    private var base: ResumeDocument {
        var document = ResumeDocument.blank
        document.sections[0].entries = [ResumeEntry(title: "iOS Engineer"), ResumeEntry(title: "Intern")]
        return document
    }

    @Test func identicalVersionsHaveNoChanges() {
        let document = base  // `base` makes new entry ids on every read
        #expect(ResumeDiff.changes(from: document, to: document).isEmpty)
    }

    @Test func describesEntrySectionAndFormatChanges() {
        let old = base
        var new = old
        new.summary = "New summary"
        new.sections[0].entries[0].title = "Senior iOS Engineer"
        new.sections[0].entries.remove(at: 1)
        new.sections[0].entries.append(ResumeEntry(title: "Lead"))
        new.sections.removeAll { $0.kind == .projects }
        new.format.font = .georgia

        let texts = Set(ResumeDiff.changes(from: old, to: new).map(\.text))
        #expect(texts == [
            "Summary edited",
            "Projects section removed",
            "Experience: added “Lead”",
            "Experience: removed “Intern”",
            "Experience: edited “Senior iOS Engineer”",
            "Font: Helvetica Neue → Georgia",
        ])
    }

    @Test func noticesReorderedSectionsAndEntries() {
        let old = base
        var new = old
        new.sections.swapAt(0, 1)
        new.sections[1].entries.reverse()
        let texts = ResumeDiff.changes(from: old, to: new).map(\.text)
        #expect(texts == ["Sections reordered", "Experience: entries reordered"])
    }

    @Test func firstSaveRecordsCreatedAndDuplicatesAreSkipped() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let editor = RecordEditor(creating: Resume(title: "Resume", document: base), in: context)
        #expect(editor.save())
        #expect(editor.record.history.map(\.reason) == [.created])

        #expect(editor.record.recordSnapshot(.exported, in: context) == nil)  // same content
        editor.record.recordSnapshot(.checkpoint, name: "Kept anyway", in: context)
        try context.save()
        #expect(editor.record.snapshots.count == 2)

        context.delete(editor.record)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ResumeSnapshot>()) == 0)
    }
}
