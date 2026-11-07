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

/// Supporting documents as a gallery, filterable by kind (FR-022).
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
            order: { $0.createdAt > $1.createdAt },
            cardWidth: 170,
            makeRecord: { SupportingDocument(name: "", fileName: "", data: Data()) },
            onAdd: { isChoosing = true },
            card: { DocumentCard(document: $0) },
            editor: { DocumentForm(editor: $0) }
        )
        .id(kind)
        .toolbar {
            ToolbarItem(placement: .navigation) {
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

/// A document in the gallery: its thumbnail, name, kind, and the record it supports.
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
                Text([document.kind.title, document.linkedRecord?.displayTitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A document's preview and details: name, kind, notes, and the record it supports.
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
                Picker("Linked To", selection: linkedRecord) {
                    Text("None").tag(UUID?.none)
                    recordGroup(String(localized: "Experience"), experiences)
                    recordGroup(String(localized: "Education"), education)
                    recordGroup(String(localized: "Projects"), projects)
                    recordGroup(String(localized: "Achievements"), achievements)
                    recordGroup(String(localized: "Certifications"), certifications)
                    recordGroup(String(localized: "Applications"), applications)
                }
            } footer: {
                Text("Linking shows this document on that record. It doesn't change the record.")
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

    @ViewBuilder
    private func recordGroup(_ title: String, _ records: [some DocumentHolder]) -> some View {
        if !records.isEmpty {
            Section(title) {
                ForEach(records, id: \.id) { Text($0.displayTitle).tag(UUID?.some($0.id)) }
            }
        }
    }

    private var allRecords: [any DocumentHolder] {
        experiences as [any DocumentHolder] + education + projects + achievements + certifications + applications
    }

    private var linkedRecord: Binding<UUID?> {
        Binding(
            get: { editor.record.linkedRecord?.id },
            set: { id in
                let record = allRecords.first { $0.id == id }
                editor.update { $0.link(to: record) }
            }
        )
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
