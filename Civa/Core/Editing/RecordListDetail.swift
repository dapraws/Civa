//
//  RecordListDetail.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Records of one type: a list on the left and an inline editor on the right (FR-010).
/// Selecting, adding, and leaving all go through the unsaved-changes guard.
struct RecordListDetail<Model: EditableRecord, Editor: View>: View {
    struct EmptyState {
        let title: String
        let message: String
        let systemImage: String
    }

    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query private var records: [Model]
    @State private var selection: Model.ID?
    /// The row clicked while the unsaved-changes prompt is up.
    @State private var pendingSelection: Model.ID??
    @State private var editor: RecordEditor<Model>?

    private let addTitle: String
    private let empty: EmptyState
    private let order: (Model, Model) -> Bool
    private let subtitle: (Model) -> String
    private let makeRecord: () -> Model
    private let editorView: (RecordEditor<Model>) -> Editor

    init(
        addTitle: String,
        empty: EmptyState,
        filter: Predicate<Model>? = nil,
        order: @escaping (Model, Model) -> Bool,
        subtitle: @escaping (Model) -> String,
        makeRecord: @escaping () -> Model,
        @ViewBuilder editor: @escaping (RecordEditor<Model>) -> Editor
    ) {
        _records = Query(FetchDescriptor(predicate: filter))
        self.addTitle = addTitle
        self.empty = empty
        self.order = order
        self.subtitle = subtitle
        self.makeRecord = makeRecord
        self.editorView = editor
    }

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addRecord) {
                        Label(addTitle, systemImage: "plus")
                    }
                    .keyboardShortcut("n")
                    .help("\(addTitle) (⌘N)")
                }
            }
            .onAppear {
                if navigation.startsNewRecord {
                    navigation.startsNewRecord = false
                    addRecord()
                } else {
                    selectFirst()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if records.isEmpty && editor == nil {
            ContentUnavailableView {
                Label(empty.title, systemImage: empty.systemImage)
            } description: {
                Text(empty.message)
            } actions: {
                Button(addTitle, action: addRecord)
            }
        } else {
            // A fixed list width keeps the layout inside the window; HSplitView sizes panes by their
            // ideal widths and overflowed with the resume editor.
            HStack(spacing: 0) {
                List(selection: changes.selection($selection, pending: $pendingSelection, apply: open)) {
                    ForEach(records.sorted(by: order)) { record in
                        RecordRow(
                            title: record.displayTitle,
                            subtitle: subtitle(record),
                            needsReview: record.needsReview
                        )
                        .tag(record.id)
                    }
                }
                .frame(width: 260)

                Divider()

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let editor {
            editorView(editor)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    RecordEditorBar(editor: editor, onClose: close)
                }
                .id(editor.record.id)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: empty.systemImage,
                description: Text("Select an item from the list.")
            )
        }
    }

    /// Like Notes and Mail, a list opens with its first record selected.
    private func selectFirst() {
        guard editor == nil, let first = records.sorted(by: order).first else { return }
        open(first.id)
    }

    private func open(_ id: Model.ID?) {
        selection = id
        editor = records.first { $0.id == id }.map { RecordEditor(record: $0, context: context) }
        changes.active = editor
    }

    private func addRecord() {
        changes.perform {
            let editor = RecordEditor(creating: makeRecord(), in: context)
            self.editor = editor
            selection = editor.record.id
            changes.active = editor
        }
    }

    private func close() {
        editor = nil
        selection = nil
        changes.active = nil
    }
}

#Preview {
    RecordListDetail<Skill, _>(
        addTitle: "Add Skill",
        empty: .init(title: "No Skills Yet", message: "Add the skills you use.", systemImage: "star"),
        order: { $0.name < $1.name },
        subtitle: \.category,
        makeRecord: { Skill(name: "") }
    ) { editor in
        Form {
            TextField("Name", text: editor.binding(\.name))
        }
        .formStyle(.grouped)
    }
    .frame(width: 800, height: 500)
    .previewEnvironment()
}
