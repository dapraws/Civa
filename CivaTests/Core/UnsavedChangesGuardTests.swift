//
//  UnsavedChangesGuardTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import Testing
@testable import Civa

@MainActor
struct UnsavedChangesGuardTests {
    final class FakeSession: EditSession {
        let title = "Acme"
        var isDirty = true
        var saveSucceeds = true
        private(set) var saves = 0
        private(set) var discards = 0

        func save() -> Bool {
            saves += 1
            if saveSucceeds { isDirty = false }
            return saveSucceeds
        }

        func discard() {
            discards += 1
            isDirty = false
        }
    }

    final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    let changes = UnsavedChangesGuard()
    let session = FakeSession()
    let ran = Box(false)
    let cancelled = Box(false)

    init() {
        changes.active = session
    }

    private func navigate() {
        changes.perform(onCancel: { cancelled.value = true }) { ran.value = true }
    }

    @Test func cleanEditorIsDiscardedAndActionRunsAtOnce() {
        session.isDirty = false
        navigate()

        #expect(ran.value)
        #expect(session.discards == 1)
        #expect(changes.active == nil)
        #expect(!changes.isPrompting)
    }

    @Test func dirtyEditorPromptsInsteadOfRunning() {
        navigate()

        #expect(!ran.value)
        #expect(changes.isPrompting)
    }

    @Test func saveThenRun() {
        navigate()
        changes.resolve(.save)

        #expect(session.saves == 1)
        #expect(ran.value)
        #expect(changes.active == nil)
    }

    @Test func failedSaveStaysOnTheRecord() {
        session.saveSucceeds = false
        navigate()
        changes.resolve(.save)

        #expect(!ran.value)
        #expect(cancelled.value)
        #expect(changes.active === session)
        #expect(!changes.isPrompting)
    }

    @Test func dontSaveDiscardsThenRuns() {
        navigate()
        changes.resolve(.discard)

        #expect(session.discards == 1)
        #expect(ran.value)
    }

    @Test func cancelKeepsTheEdits() {
        navigate()
        changes.resolve(.cancel)

        #expect(!ran.value)
        #expect(cancelled.value)
        #expect(session.isDirty)
        #expect(changes.active === session)
    }

    @Test func selectionControlRevertsOnCancel() {
        let shown = Box("Dashboard")
        let applied = Box<String?>(nil)
        let binding = changes.selection(Binding(get: { shown.value }, set: { shown.value = $0 })) {
            applied.value = $0
        }

        binding.wrappedValue = "Resumes"
        #expect(shown.value == "Resumes")
        #expect(applied.value == nil)

        changes.resolve(.cancel)
        #expect(shown.value == "Dashboard")
        #expect(applied.value == nil)
    }
}
