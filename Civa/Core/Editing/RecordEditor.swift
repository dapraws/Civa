//
//  RecordEditor.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Observation
import SwiftData
import SwiftUI

/// What the unsaved-changes guard needs from whichever editor is active.
protocol EditSession: AnyObject {
    var title: String { get }
    var isDirty: Bool { get }
    /// Validates and saves. Returns false, keeping the edits, when that fails.
    func save() -> Bool
    /// Drops unsaved edits, including a new record that was never saved.
    func discard()
}

/// Edits one record in place in the main context, which has autosave off.
/// Save validates then commits; discard rolls back. Only the active editor leaves
/// pending changes (the guard resolves it before anything else runs), so a
/// context-wide save or rollback touches nothing else.
@Observable
final class RecordEditor<Model: EditableRecord>: EditSession {
    let record: Model
    private(set) var isNew: Bool
    private(set) var isDirty = false
    private(set) var errors: [PartialKeyPath<Model>: String] = [:]
    /// Set when the store rejects a write; shown as an alert.
    var storeError: String?

    @ObservationIgnored private let context: ModelContext

    init(record: Model, context: ModelContext) {
        self.record = record
        self.context = context
        self.isNew = false
    }

    /// Starts a new, unsaved record. It shows in lists right away and disappears on discard.
    init(creating record: Model, in context: ModelContext) {
        context.insert(record)
        self.record = record
        self.context = context
        self.isNew = true
    }

    var title: String { record.displayTitle }

    func error(for field: PartialKeyPath<Model>) -> String? { errors[field] }

    /// Binding for a form field. Editing marks the record dirty and clears the field's error.
    func binding<Value: Equatable>(_ field: ReferenceWritableKeyPath<Model, Value>) -> Binding<Value> {
        Binding(
            get: { self.record[keyPath: field] },
            set: { newValue in
                guard self.record[keyPath: field] != newValue else { return }
                self.record[keyPath: field] = newValue
                self.errors[field] = nil
                self.isDirty = true
            }
        )
    }

    /// For edits a single binding can't express, such as relationship changes.
    func update(_ change: (Model) -> Void) {
        change(record)
        isDirty = true
    }

    @discardableResult
    func save() -> Bool {
        errors = record.validationErrors()
        guard errors.isEmpty else { return false }
        record.updatedAt = .now
        do {
            try context.save()
            isNew = false
            isDirty = false
            return true
        } catch {
            storeError = error.localizedDescription
            return false
        }
    }

    func discard() {
        context.rollback()
        errors = [:]
        isDirty = false
    }

    /// Deletes the record, dropping unsaved edits first. Returns false when the store rejects it.
    func delete() -> Bool {
        context.rollback()
        guard !isNew else { return true }  // the rollback already removed it
        context.delete(record)
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            storeError = error.localizedDescription
            return false
        }
    }
}

extension RecordEditor where Model: ProfileRecord {
    /// Marks the record confirmed and saves it along with any other edits.
    @discardableResult
    func confirm() -> Bool {
        update { $0.status = .confirmed }
        return save()
    }
}
