//
//  RecordEditorTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Civa

@MainActor
struct RecordEditorTests {
    let container: ModelContainer

    init() throws {
        container = try .civa(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    /// What the store holds, seen from a context with no pending edits.
    private func stored<M: PersistentModel>(_ type: M.Type) throws -> [M] {
        try ModelContext(container).fetch(FetchDescriptor<M>())
    }

    @Test func mainContextDoesNotAutosave() {
        #expect(!context.autosaveEnabled)
    }

    @Test func saveCommitsValidEdits() throws {
        let editor = RecordEditor(creating: Experience(kind: .professional, organization: "", role: ""), in: context)
        editor.binding(\.organization).wrappedValue = "Acme"
        editor.binding(\.role).wrappedValue = "iOS Engineer"
        #expect(editor.isDirty)

        #expect(editor.save())
        #expect(!editor.isDirty)
        #expect(!editor.isNew)
        #expect(try stored(Experience.self).map(\.role) == ["iOS Engineer"])
    }

    @Test func invalidRecordIsNotSavedAndEditingClearsTheError() throws {
        let editor = RecordEditor(creating: Experience(kind: .professional, organization: "Acme", role: "  "), in: context)
        editor.update { _ in }

        #expect(!editor.save())
        #expect(editor.error(for: \.role) != nil)
        #expect(try stored(Experience.self).isEmpty)

        editor.binding(\.role).wrappedValue = "Intern"
        #expect(editor.error(for: \.role) == nil)
    }

    @Test func settingTheSameValueDoesNotMarkDirty() throws {
        let record = Skill(name: "Swift")
        context.insert(record)
        try context.save()
        let editor = RecordEditor(record: record, context: context)

        editor.binding(\.name).wrappedValue = "Swift"
        #expect(!editor.isDirty)
    }

    @Test func discardRestoresSavedValues() throws {
        let record = Experience(kind: .professional, organization: "Acme", role: "Intern")
        context.insert(record)
        try context.save()
        let editor = RecordEditor(record: record, context: context)

        editor.binding(\.role).wrappedValue = "Lead"
        editor.discard()

        #expect(record.role == "Intern")
        #expect(!editor.isDirty)
    }

    @Test func discardingANewRecordRemovesIt() throws {
        let editor = RecordEditor(creating: Skill(name: "Swift"), in: context)
        #expect(try context.fetchCount(FetchDescriptor<Skill>()) == 1)

        editor.discard()
        #expect(try context.fetchCount(FetchDescriptor<Skill>()) == 0)
    }

    @Test func deleteDropsEditsAndRemovesTheRecord() throws {
        let record = Skill(name: "Swift")
        context.insert(record)
        try context.save()
        let editor = RecordEditor(record: record, context: context)
        editor.binding(\.name).wrappedValue = "Swift 6"

        #expect(editor.delete())
        #expect(try stored(Skill.self).isEmpty)
    }

    @Test func confirmMarksTheRecordConfirmedAndSaves() throws {
        let record = Skill(name: "Swift", status: .needsReview)
        context.insert(record)
        try context.save()
        let editor = RecordEditor(record: record, context: context)

        #expect(editor.confirm())
        #expect(try stored(Skill.self).first?.status == .confirmed)
    }
}
