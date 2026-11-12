//
//  RecordListDetail.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// What a record page shows before anything has been added.
struct RecordEmptyState {
    let title: String
    let message: String
    let systemImage: String
    /// A filtered list that came up empty has nothing to add from (DESIGN.md §8.7).
    var showsAddButton = true
}

/// Records of one type: a list on the left and an inline editor on the right (FR-010).
/// Selecting, adding, and leaving all go through the unsaved-changes guard.
struct RecordListDetail<Model: EditableRecord, Editor: View>: View {
    typealias EmptyState = RecordEmptyState

    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query private var records: [Model]
    @State private var selection: Model.ID?
    /// The row clicked while the unsaved-changes prompt is up.
    @State private var pendingSelection: Model.ID??
    @State private var editor: RecordEditor<Model>?
    /// Makes this list's Add action unique, so a rebuilt list (Applications' `.id(status)`)
    /// replaces the title row's button instead of leaving the old list's.
    @State private var actionToken = UUID()
    @FocusState private var isListFocused: Bool

    private let addTitle: String
    private let empty: EmptyState
    private let order: (Model, Model) -> Bool
    private let subtitle: (Model) -> String
    private let makeRecord: () -> Model
    private let editorView: (RecordEditor<Model>) -> Editor
    /// Replaces the standard row, such as Applications' logo and status mark.
    private let row: ((Model, Bool) -> AnyView)?
    /// Applications draw their own header with the logo and status.
    private let showsTitle: Bool

    init(
        addTitle: String,
        empty: EmptyState,
        filter: Predicate<Model>? = nil,
        order: @escaping (Model, Model) -> Bool,
        subtitle: @escaping (Model) -> String,
        makeRecord: @escaping () -> Model,
        showsTitle: Bool = true,
        row: ((Model, Bool) -> AnyView)? = nil,
        @ViewBuilder editor: @escaping (RecordEditor<Model>) -> Editor
    ) {
        self.row = row
        self.showsTitle = showsTitle
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
            .pageAction(PageAction(id: "\(addTitle)#\(actionToken)", title: addTitle, systemImage: "plus", shortcut: "n", run: addRecord))
            .onChange(of: navigation.recordToOpen) { _, target in
                guard let target, let record = records.first(where: { AnyHashable($0.id) == target }) else { return }
                navigation.recordToOpen = nil
                open(record.id)
            }
            .onAppear {
                if navigation.startsNewRecord {
                    navigation.startsNewRecord = false
                    addRecord()
                } else if let target = navigation.recordToOpen, let record = records.first(where: { AnyHashable($0.id) == target }) {
                    // Asked for before this list existed, so onChange never saw it.
                    navigation.recordToOpen = nil
                    open(record.id)
                } else {
                    selectFirst()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if records.isEmpty && editor == nil {
            EmptyStateView(
                symbol: empty.systemImage,
                title: LocalizedStringKey(empty.title),
                message: LocalizedStringKey(empty.message),
                button: empty.showsAddButton ? (LocalizedStringKey(addTitle), .primary, addRecord) : nil
            )
            .padding(.horizontal, Space.xl)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            // A fixed list width keeps the layout inside the window; HSplitView sizes panes by their
            // ideal widths and overflowed with the resume editor.
            HStack(spacing: 0) {
                list
                    .frame(width: Size.recordList)
                    .background(Color.sidebar)
                    .overlay(alignment: .trailing) { Rectangle().fill(Color.hairline).frame(width: 1) }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.canvas)
            }
        }
    }

    /// Rows draw their own selection (DESIGN.md §7.8). The list takes focus on click or Tab; arrow
    /// keys move the selection and keep it in view, and keyboard focus shows the ring on that row.
    private var list: some View {
        let sorted = records.sorted(by: order)
        let selected = changes.selection($selection, pending: $pendingSelection, apply: open)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(sorted) { record in
                        let isSelected = selected.wrappedValue == record.id
                        Group {
                            if let row {
                                row(record, isSelected)
                            } else {
                                RecordRow(
                                    title: record.displayTitle,
                                    subtitle: subtitle(record),
                                    needsReview: record.needsReview,
                                    proof: record.proof,
                                    isSelected: isSelected
                                )
                            }
                        }
                        .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isListFocused && isSelected)
                        .id(record.id)
                        .onTapGesture {
                            isListFocused = true
                            selected.wrappedValue = record.id
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selected.wrappedValue = record.id }
                    }
                }
                .padding(Space.s)
            }
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { step(-1, in: sorted, selection: selected, proxy: proxy) }
            .onKeyPress(.downArrow) { step(1, in: sorted, selection: selected, proxy: proxy) }
        }
    }

    private func step(_ offset: Int, in sorted: [Model], selection: Binding<Model.ID?>, proxy: ScrollViewProxy) -> KeyPress.Result {
        let next: Model?
        if let index = sorted.firstIndex(where: { $0.id == selection.wrappedValue }) {
            guard sorted.indices.contains(index + offset) else { return .handled }
            next = sorted[index + offset]
        } else {
            next = offset > 0 ? sorted.first : sorted.last
        }
        guard let next else { return .ignored }
        selection.wrappedValue = next.id
        proxy.scrollTo(next.id)
        return .handled
    }

    @ViewBuilder
    private var detail: some View {
        if let editor {
            VStack(alignment: .leading, spacing: 0) {
                if showsTitle {
                    Text(editor.title)
                        .font(.detailTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, Space.xl)
                        .padding(.top, 20)
                        .padding(.bottom, Space.s)
                }
                editorView(editor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RecordEditorBar(editor: editor, onClose: close)
            }
            .startsWithoutFocus(!editor.isNew)
            .id(editor.record.id)
        } else {
            EmptyStateView(symbol: empty.systemImage, title: "No Selection", message: "Select an item from the list.")
                .padding(.horizontal, Space.xl)
                .frame(maxHeight: .infinity, alignment: .top)
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
        .civaForm()
    }
    .frame(width: 800, height: 500)
    .previewEnvironment()
}
