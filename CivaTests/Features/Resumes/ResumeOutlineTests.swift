//
//  ResumeOutlineTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

struct ResumeOutlineTests {
    /// Rows: 0 Experience, 1 A, 2 B, 3 Education, 4 C, 5 Skills
    private func document() -> ResumeDocument {
        ResumeDocument(sections: [
            ResumeSection(kind: .experience, entries: [ResumeEntry(title: "A"), ResumeEntry(title: "B")]),
            ResumeSection(kind: .education, entries: [ResumeEntry(title: "C")]),
            ResumeSection(kind: .skills),
        ])
    }

    @Test func rowsListEachSectionThenItsEntries() {
        let rows = document().outlineRows
        #expect(rows.map(\.section) == [0, 0, 0, 1, 1, 2])
        #expect(rows.map(\.entry) == [nil, 0, 1, nil, 0, nil])
    }

    @Test func entryMovesWithinItsSection() {
        var document = document()
        document.moveOutlineRow(from: [2], to: 1)  // B above A
        #expect(document.sections[0].entries.map(\.title) == ["B", "A"])
    }

    @Test func entryCannotLeaveItsSection() {
        var document = document()
        document.moveOutlineRow(from: [1], to: 5)  // A into Education
        #expect(document.sections[0].entries.map(\.title) == ["A", "B"])
        #expect(document.sections[1].entries.map(\.title) == ["C"])
    }

    @Test func sectionMovesWithItsEntries() {
        var document = document()
        document.moveOutlineRow(from: [3], to: 0)  // Education to the top
        #expect(document.sections.map(\.kind) == [.education, .experience, .skills])
        #expect(document.sections[0].entries.map(\.title) == ["C"])
    }

    @Test func sectionDroppedAmongEntriesLandsAfterThatSection() {
        var document = document()
        document.moveOutlineRow(from: [5], to: 2)  // Skills between A and B
        #expect(document.sections.map(\.kind) == [.experience, .skills, .education])
    }

    @Test func findsEntryPosition() {
        let document = document()
        let id = document.sections[1].entries[0].id
        #expect(document.entryPosition(id)! == (1, 0))
    }
}
