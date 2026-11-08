//
//  DocumentsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Supporting documents as a gallery grouped by kind under a heading each, filterable by kind (FR-022).
struct DocumentsView: View {
    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    /// nil shows every kind.
    @State private var kind: DocumentKind?
    @State private var pendingKind: DocumentKind??
    @State private var isChoosing = false
    @State private var saveError: String?

    var body: some View {
        RecordGallery(
            title: String(localized: "Documents"),
            addTitle: String(localized: "Add Document"),
            empty: .init(
                title: kind == nil ? String(localized: "No Documents Yet") : String(localized: "No Documents Here"),
                message: String(localized: "Add certificates, project files, and portfolio pieces, or drop them here. Civa keeps its own copy on this Mac."),
                systemImage: AppSection.documents.systemImage
            ),
            filter: kind.map { raw in #Predicate<SupportingDocument> { $0.kindRaw == raw.rawValue } },
            order: SupportingDocument.galleryOrder,
            cardWidth: 170,
            makeRecord: { SupportingDocument(name: "", fileName: "", data: Data()) },
            section: { $0.kind.groupTitle },
            onAdd: { isChoosing = true },
            card: { DocumentCard(document: $0) },
            editor: { DocumentForm(editor: $0) }
        )
        .id(kind)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Kind", selection: changes.selection($kind, pending: $pendingKind)) {
                    Text("All Kinds").tag(DocumentKind?.none)
                    Divider()
                    ForEach(DocumentKind.allCases) { Text($0.title).tag(DocumentKind?.some($0)) }
                }
                .help("Show documents of this kind")
            }
        }
        .documentAdder(isChoosing: $isChoosing) { files in
            guard changes.active == nil else { return }  // an open editor saves its own changes
            DocumentFiles.insert(files, linkedTo: nil, in: context)
            do {
                try context.save()
            } catch {
                context.rollback()
                saveError = error.localizedDescription
            }
        }
        .alert(
            "Civa Couldn't Add the Documents",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

/// A document in the gallery: its thumbnail, name, kind, and the records it supports.
struct DocumentCard: View {
    let document: SupportingDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DocumentThumbnail(document: document)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.separator) }
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text([document.kind.title, linkedSummary].compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var linkedSummary: String? {
        let linked = document.linkedRecords
        return switch linked.count {
        case 0: nil
        case 1: linked[0].displayTitle
        default: String(localized: "\(linked.count) records")
        }
    }
}

/// A document's preview and details: name, kind, notes, and the records it supports.
struct DocumentForm: View {
    let editor: RecordEditor<SupportingDocument>

    @Query(sort: \Experience.role) private var experiences: [Experience]
    @Query(sort: \Education.institution) private var education: [Education]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Achievement.title) private var achievements: [Achievement]
    @Query(sort: \Certification.name) private var certifications: [Certification]
    @Query(sort: \JobApplication.company) private var applications: [JobApplication]
    @State private var previewURL: URL?
    @State private var importRequest: ImportRequest?

    var body: some View {
        let document = editor.record
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    DocumentThumbnail(document: document, size: 220)
                        .frame(width: 160, height: 160)
                        .clipShape(.rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.fileName)
                            .font(.headline)
                            .textSelection(.enabled)
                        Text("\(document.data.count.formatted(.byteCount(style: .file))) · Added \(document.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(.secondary)
                        Button("Preview", systemImage: "eye") { previewURL = document.fileURL() }
                        if canImport(document) {
                            Button("Import Details from This…", systemImage: "square.and.arrow.down") {
                                if let url = document.fileURL() { importRequest = ImportRequest(url: url, kind: .cv) }
                            }
                            .help("Review details found in this file before adding them to your Career Profile")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                TextField("Name", text: editor.binding(\.name), prompt: Text("Required"))
                FieldError(editor.error(for: \.name))
                Picker("Kind", selection: editor.binding(\.kindRaw)) {
                    ForEach(DocumentKind.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section {
                ForEach(document.linkedRecords, id: \.id) { record in
                    HStack {
                        Text(record.displayTitle)
                        Spacer()
                        Text(Self.recordKind(record))
                            .foregroundStyle(.secondary)
                        Button("Unlink", systemImage: "xmark.circle.fill") {
                            editor.update { $0.detach(from: record) }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Take the document off this record. The document stays.")
                    }
                }
                Menu("Link to a Record") {
                    recordGroup(String(localized: "Experience"), experiences)
                    recordGroup(String(localized: "Education"), education)
                    recordGroup(String(localized: "Projects"), projects)
                    recordGroup(String(localized: "Achievements"), achievements)
                    recordGroup(String(localized: "Certifications"), certifications)
                    recordGroup(String(localized: "Applications"), applications)
                }
                .fixedSize()
            } header: {
                Text("Linked To")
            } footer: {
                Text("One document can go on many records, like a transcript on several applications. Linking doesn't change the record.")
            }
            Section("Notes") {
                TextField("Notes", text: editor.binding(\.notes), prompt: Text("Where it's from, what it shows"), axis: .vertical)
                    .labelsHidden()
                    .lineLimit(3...8)
            }
        }
        .formStyle(.grouped)
        .quickLookPreview($previewURL)
        .sheet(item: $importRequest) { ImportReviewSheet(request: $0) }
    }

    /// A submenu of the records of one type that this document isn't on yet.
    @ViewBuilder
    private func recordGroup(_ title: String, _ records: [some DocumentHolder]) -> some View {
        let open = records.filter { !editor.record.isLinked(to: $0) }
        if !open.isEmpty {
            Menu(title) {
                ForEach(open, id: \.id) { record in
                    Button(record.displayTitle) { editor.update { $0.attach(to: record) } }
                }
            }
        }
    }

    static func recordKind(_ record: any DocumentHolder) -> String {
        switch record {
        case is Experience: String(localized: "Experience")
        case is Education: String(localized: "Education")
        case is Project: String(localized: "Project")
        case is Achievement: String(localized: "Achievement")
        case is Certification: String(localized: "Certification")
        default: String(localized: "Application")
        }
    }

    private func canImport(_ document: SupportingDocument) -> Bool {
        CVTextExtractor.contentTypes.contains { document.contentType?.conforms(to: $0) == true }
    }
}

#Preview {
    NavigationStack {
        DocumentsView()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}
