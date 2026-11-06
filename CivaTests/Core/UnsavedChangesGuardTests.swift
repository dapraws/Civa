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

    private func selectionBinding(_ value: Box<String>, _ pending: Box<String?>) -> Binding<String> {
        changes.selection(
            Binding(get: { value.value }, set: { value.value = $0 }),
            pending: Binding(get: { pending.value }, set: { pending.value = $0 })
        )
    }

    @Test func selectionShowsTheClickWhilePromptingAndCancelRestoresIt() {
        let value = Box("Dashboard")
        let pending = Box<String?>(nil)
        let binding = selectionBinding(value, pending)

        binding.wrappedValue = "Resumes"
        #expect(binding.wrappedValue == "Resumes")
        #expect(value.value == "Dashboard")

        changes.resolve(.cancel)
        #expect(binding.wrappedValue == "Dashboard")
        #expect(pending.value == nil)
    }

    @Test func selectionCommitsOnceResolved() {
        let value = Box("Dashboard")
        let pending = Box<String?>(nil)
        let binding = selectionBinding(value, pending)

        binding.wrappedValue = "Resumes"
        changes.resolve(.discard)
        #expect(value.value == "Resumes")
        #expect(pending.value == nil)
    }

    @Test func selectionCommitsAtOnceWhenNothingIsUnsaved() {
        session.isDirty = false
        let value = Box("Dashboard")
        let pending = Box<String?>(nil)

        selectionBinding(value, pending).wrappedValue = "Resumes"
        #expect(value.value == "Resumes")
        #expect(!changes.isPrompting)
    }
}
