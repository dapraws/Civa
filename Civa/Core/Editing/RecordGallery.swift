//
//  RecordGallery.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Records of one type as a grid of cards. Opening a card fills the page with its editor, and the
/// back button returns to the grid. Leaving the editor goes through the unsaved-changes guard.
struct RecordGallery<Model: EditableRecord, Card: View, Editor: View>: View {
    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query private var records: [Model]
    @State private var editor: RecordEditor<Model>?
    @State private var deleting: Model?
    @State private var storeError: String?

    private let title: String
    private let addTitle: String
    private let empty: RecordEmptyState
    private let order: (Model, Model) -> Bool
    private let cardWidth: CGFloat
    private let makeRecord: () -> Model
    private let duplicate: ((Model) -> Model)?
    private let card: (Model) -> Card
    private let editorView: (RecordEditor<Model>) -> Editor

    init(
        title: String,
        addTitle: String,
        empty: RecordEmptyState,
        filter: Predicate<Model>? = nil,
        order: @escaping (Model, Model) -> Bool,
        cardWidth: CGFloat,
        makeRecord: @escaping () -> Model,
        duplicate: ((Model) -> Model)? = nil,
        @ViewBuilder card: @escaping (Model) -> Card,
        @ViewBuilder editor: @escaping (RecordEditor<Model>) -> Editor
    ) {
        _records = Query(FetchDescriptor(predicate: filter))
        self.title = title
        self.addTitle = addTitle
        self.empty = empty
        self.order = order
        self.cardWidth = cardWidth
        self.makeRecord = makeRecord
        self.duplicate = duplicate
        self.card = card
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
            .onChange(of: navigation.recordToOpen) { openRequestedRecord() }
            .onAppear {
                openRequestedRecord()
                if navigation.startsNewRecord {
                    navigation.startsNewRecord = false
                    addRecord()
                }
                #if DEBUG
                // Manual checks: -CivaOpenFirst YES opens the first card.
                if UserDefaults.standard.bool(forKey: "CivaOpenFirst"), let first = records.sorted(by: order).first {
                    open(first)
                }
                #endif
            }
            .confirmationDialog(
                "Delete “\(deleting?.displayTitle ?? "")”?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("Delete", role: .destructive) {
                    if let deleting { write { context.delete(deleting) } }
                }
            } message: {
                Text("This can't be undone.")
            }
            .alert(
                "Civa Couldn't Save Your Changes",
                isPresented: Binding(get: { storeError != nil }, set: { if !$0 { storeError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(storeError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let editor {
            editorView(editor)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    RecordEditorBar(editor: editor, onClose: close)
                }
                .id(editor.record.id)
                .navigationTitle(editor.title)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            changes.perform(close)
                        } label: {
                            Label(title, systemImage: "chevron.backward")
                        }
                        .help("Back to \(title)")
                    }
                }
        } else if records.isEmpty {
            ContentUnavailableView {
                Label(empty.title, systemImage: empty.systemImage)
            } description: {
                Text(empty.message)
            } actions: {
                Button(addTitle, action: addRecord)
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth * 1.4), spacing: 20, alignment: .top)],
                    spacing: 24
                ) {
                    ForEach(records.sorted(by: order)) { record in
                        Button { open(record) } label: {
                            card(record).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open") { open(record) }
                            if let duplicate {
                                Button("Duplicate") { write { context.insert(duplicate(record)) } }
                            }
                            Divider()
                            Button("Delete…", role: .destructive) { deleting = record }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    /// Opens a record another page asked for (a new resume from a sheet, a resume linked to an application).
    private func openRequestedRecord() {
        guard let target = navigation.recordToOpen,
              let record = records.first(where: { AnyHashable($0.id) == target })
        else { return }
        navigation.recordToOpen = nil
        open(record)
    }

    private func open(_ record: Model) {
        changes.perform {
            let editor = RecordEditor(record: record, context: context)
            self.editor = editor
            changes.active = editor
        }
    }

    private func addRecord() {
        changes.perform {
            let editor = RecordEditor(creating: makeRecord(), in: context)
            self.editor = editor
            changes.active = editor
        }
    }

    private func close() {
        editor = nil
        changes.active = nil
    }

    /// Gallery actions save right away; the gallery never holds unsaved edits.
    private func write(_ change: () -> Void) {
        change()
        do {
            try context.save()
        } catch {
            context.rollback()
            storeError = error.localizedDescription
        }
    }
}

#Preview {
    RecordGallery<JobApplication, _, _>(
        title: "Applications",
        addTitle: "Add Application",
        empty: .init(title: "No Applications Yet", message: "Track the jobs you want.", systemImage: "tray"),
        order: { $0.createdAt > $1.createdAt },
        cardWidth: 200,
        makeRecord: { JobApplication(company: "", position: "") }
    ) { application in
        Text(application.displayTitle)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(.quaternary, in: .rect(cornerRadius: 12))
    } editor: { editor in
        Form {
            TextField("Position", text: editor.binding(\.position))
        }
        .formStyle(.grouped)
    }
    .frame(width: 900, height: 500)
    .previewEnvironment()
}
