//
//  RecordEditorBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Bar under an inline editor: unsaved marker, Delete, Revert, and Save (⌘S).
struct RecordEditorBar<Model: EditableRecord>: View {
    let editor: RecordEditor<Model>
    /// Delete is offered only when this is set.
    var canDelete = true
    /// Called when the record goes away (deleted, or a new record reverted).
    let onClose: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        HStack {
            if editor.isDirty {
                Label("Unsaved Changes", systemImage: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if canDelete {
                Button("Delete…", role: .destructive) { isConfirmingDelete = true }
            }
            Button("Revert", action: revert)
                .disabled(!editor.isDirty)
            Button("Save") { editor.save() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!editor.isDirty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(
            "Delete “\(editor.title)”?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                if editor.delete() { onClose() }
            }
        } message: {
            Text("This can't be undone.")
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
