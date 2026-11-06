//
//  RecordGallery.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// An extra right-click action on a gallery card. It's saved as soon as it runs.
struct GalleryAction<Model> {
    let title: (Model) -> String
    let run: (Model, ModelContext) throws -> Void
}

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
    private let section: ((Model) -> String)?
    private let actions: [GalleryAction<Model>]
    private let showsAddButton: Bool
    /// Replaces "add a blank record", for records that start from something else (a file).
    private let onAdd: (() -> Void)?
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
        section: ((Model) -> String)? = nil,
        actions: [GalleryAction<Model>] = [],
        showsAddButton: Bool = true,
        onAdd: (() -> Void)? = nil,
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
        self.section = section
        self.actions = actions
        self.showsAddButton = showsAddButton
        self.onAdd = onAdd
        self.card = card
        self.editorView = editor
    }

    var body: some View {
        content
            .toolbar {
                if showsAddButton {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: addRecord) {
                            Label(addTitle, systemImage: "plus")
                        }
                        .keyboardShortcut("n")
                        .help("\(addTitle) (⌘N)")
                    }
                }
            }
            .onChange(of: navigation.recordToOpen) { openRequestedRecord() }
            // A page's own New menu asks for a blank record this way.
            .onChange(of: navigation.startsNewRecord) { _, starts in
                guard starts else { return }
                navigation.startsNewRecord = false
                addRecord()
            }
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
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.records) { record in
                                cardButton(record)
                            }
                        } header: {
                            if let title = group.title {
                                Text(title)
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private func cardButton(_ record: Model) -> some View {
        Button { open(record) } label: {
            card(record).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { open(record) }
            if let duplicate {
                Button("Duplicate") { write { context.insert(duplicate(record)) } }
            }
            ForEach(actions.indices, id: \.self) { index in
                Button(actions[index].title(record)) { write { try actions[index].run(record, context) } }
            }
            Divider()
            Button("Delete…", role: .destructive) { deleting = record }
        }
    }

    /// Sorted records in runs of the same section. With only one section, no headings show.
    private var groups: [(title: String?, records: [Model])] {
        let sorted = records.sorted(by: order)
        guard let section else { return [(nil, sorted)] }
        var groups: [(title: String?, records: [Model])] = []
        for record in sorted {
            let title = section(record)
            if groups.last?.title == title {
                groups[groups.count - 1].records.append(record)
            } else {
                groups.append((title, [record]))
            }
        }
        return groups.count > 1 ? groups : [(nil, sorted)]
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
        if let onAdd {
            return changes.perform {
                close()
                onAdd()
            }
        }
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
    private func write(_ change: () throws -> Void) {
        do {
            try change()
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
