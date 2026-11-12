//
//  RecordEditorBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Bar under an inline editor: unsaved marker, where the record came from, Compare and Merge for a
/// possible duplicate, Delete, Revert, and Save (⌘S).
struct RecordEditorBar<Model: EditableRecord>: View {
    let editor: RecordEditor<Model>
    /// Delete is offered only when this is set.
    var canDelete = true
    /// Called when the record goes away (deleted, or a new record reverted).
    let onClose: () -> Void

    @Environment(AppNavigation.self) private var navigation
    @State private var isConfirmingDelete = false
    @State private var isMerging = false

    var body: some View {
        HStack {
            if editor.isDirty {
                Label("Unsaved Changes", systemImage: "pencil.circle")
                    .foregroundStyle(Color.textSecondary)
            } else if let record = editor.record as? any ProfileRecord, !record.sources.isEmpty {
                Text("Source: \(record.sources.map(\.title).joined(separator: " · "))")
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .help(record.sources.map(\.title).joined(separator: "\n"))
            }
            Spacer()
            if let duplicate = editor.record as? any ImportableRecord, duplicate.possibleDuplicateOf != nil {
                Button("Possible Duplicate…", systemImage: "square.on.square") {
                    // Merging saves straight to the store, so unsaved edits go first.
                    if !editor.isDirty || editor.save() { isMerging = true }
                }
                .civaButton(.secondary)
                .help("Compare with the record this may repeat, then merge or keep both")
                .sheet(isPresented: $isMerging) {
                    DuplicateMergeSheet(duplicate: duplicate, onMerged: onClose)
                }
            }
            if canDelete {
                Button("Delete…", role: .destructive) { isConfirmingDelete = true }
                    .civaButton(.destructive)
            }
            Button("Revert", action: revert)
                .civaButton(.secondary)
                .disabled(!editor.isDirty)
            Button("Save") {
                let wasNew = editor.isNew
                if editor.save(), wasNew { navigation.justSavedRecordID = editor.record.id as? UUID }
            }
                .keyboardShortcut("s")
                .civaButton(.primary)
                .disabled(!editor.isDirty)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, 10)
        .background(Color.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .confirmationDialog(
            "Delete “\(editor.title)”?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                if editor.delete() { onClose() }
            }
        } message: {
            Text(SupportingDocument.deleteMessage(for: editor.record))
        }
        .alert(
            "Civa Couldn't Save Your Changes",
            isPresented: Binding(
                get: { editor.storeError != nil },
                set: { if !$0 { editor.storeError = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(editor.storeError ?? "")
        }
    }

    private func revert() {
        navigation.revertCount += 1
        editor.discard()
        if editor.isNew { onClose() }  // the record never existed
    }
}

#Preview {
    VStack {
        Spacer()
        RecordEditorBar(editor: RecordEditor<Experience>.preview(), onClose: {})
    }
    .frame(width: 600, height: 200)
    .previewEnvironment()
}

extension EnvironmentValues {
    /// Closes the editor hosting this view, for actions inside it that end the edit (like discarding a draft).
    @Entry var closeRecordEditor: () -> Void = {}
}
