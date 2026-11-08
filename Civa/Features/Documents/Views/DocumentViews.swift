//
//  DocumentViews.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import QuickLook
import QuickLookThumbnailing
import SwiftData
import SwiftUI

/// Reads chosen or dropped files into documents (FR-022). The caller decides when to save.
enum DocumentFiles {
    struct Loaded {
        let url: URL
        let data: Data
    }

    /// Reads each file once. Unreadable ones are skipped and named in `failed`.
    static func load(_ urls: [URL]) -> (loaded: [Loaded], failed: [String]) {
        var loaded: [Loaded] = []
        var failed: [String] = []
        for url in urls {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                loaded.append(Loaded(url: url, data: data))
            } else {
                failed.append(url.lastPathComponent)
            }
        }
        return (loaded, failed)
    }

    @discardableResult
    static func insert(_ files: [Loaded], linkedTo record: (any DocumentHolder)?, in context: ModelContext) -> [SupportingDocument] {
        files.map { file in
            let fileName = file.url.lastPathComponent
            let document = SupportingDocument(
                name: (fileName as NSString).deletingPathExtension,
                fileName: fileName,
                data: file.data,
                kind: SupportingDocument.guessKind(fileName: fileName, for: record)
            )
            context.insert(document)
            if let record { document.attach(to: record) }
            return document
        }
    }
}

/// Chooses or receives files, asks before adding very large ones, then hands them over.
struct DocumentAdder: ViewModifier {
    @Binding var isChoosing: Bool
    let add: ([DocumentFiles.Loaded]) -> Void

    @State private var pendingLarge: [DocumentFiles.Loaded] = []
    @State private var failed: [String] = []

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { receive(urls) }
            }
            .dropDestination(for: URL.self) { urls, _ in
                receive(urls)
                return !urls.isEmpty
            }
            .confirmationDialog(
                "Add Large Files?",
                isPresented: Binding(get: { !pendingLarge.isEmpty }, set: { if !$0 { pendingLarge = [] } })
            ) {
                Button("Add Anyway") {
                    add(pendingLarge)
                    pendingLarge = []
                }
            } message: {
                Text("\(pendingLarge.map(\.url.lastPathComponent).joined(separator: ", ")) is over 50 MB. Civa keeps its own copy on this Mac.")
            }
            .alert(
                "Civa Couldn't Read Some Files",
                isPresented: Binding(get: { !failed.isEmpty }, set: { if !$0 { failed = [] } })
            ) {
                Button("OK") {}
            } message: {
                Text(failed.joined(separator: ", "))
            }
    }

    private func receive(_ urls: [URL]) {
        let result = DocumentFiles.load(urls)
        failed = result.failed
        let small = result.loaded.filter { $0.data.count <= SupportingDocument.largeFileSize }
        pendingLarge = result.loaded.filter { $0.data.count > SupportingDocument.largeFileSize }
        if !small.isEmpty { add(small) }
    }
}

extension View {
    func documentAdder(isChoosing: Binding<Bool>, add: @escaping ([DocumentFiles.Loaded]) -> Void) -> some View {
        modifier(DocumentAdder(isChoosing: isChoosing, add: add))
    }
}

/// The file's first page or picture, from Quick Look, with its kind's symbol until it's ready.
struct DocumentThumbnail: View {
    let document: SupportingDocument
    var size: CGFloat = 160

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: document.kind.systemImage)
                    .font(.system(size: size * 0.25))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: document.id) {
            guard let url = document.fileURL() else { return }
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: CGSize(width: size, height: size), scale: 2, representationTypes: .thumbnail
            )
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
        .accessibilityHidden(true)
    }
}

/// A row for a document attached to a record: name, size, Preview, and Detach.
struct DocumentRow: View {
    let document: SupportingDocument
    let onDetach: () -> Void

    @State private var previewURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            DocumentThumbnail(document: document, size: 36)
                .frame(width: 36, height: 36)
                .clipShape(.rect(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text(document.displayTitle)
                    .lineLimit(1)
                Text("\(document.kind.title) · \(document.data.count.formatted(.byteCount(style: .file)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Preview", systemImage: "eye") { previewURL = document.fileURL() }
            Button("Detach", systemImage: "link.badge.plus", action: onDetach)
                .help("Keep the document, but not on this record")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .quickLookPreview($previewURL)
    }
}

/// Documents attached to a record, in its editor. Attaching and detaching are
/// edits to the record, saved or reverted with it. Attach picks from Civa's Documents first,
/// so a file already kept in Civa never has to be found in Finder again.
struct DocumentsSection<Model: DocumentHolder>: View {
    let editor: RecordEditor<Model>

    @Environment(\.modelContext) private var context
    @Query private var library: [SupportingDocument]
    @State private var isChoosing = false
    @State private var showsLibrary = false

    var body: some View {
        Section {
            ForEach(editor.record.documents.sorted { $0.createdAt < $1.createdAt }) { document in
                DocumentRow(document: document) {
                    editor.update { record in document.detach(from: record) }
                }
            }
            AddButton(title: String(localized: "Attach Document…")) {
                // Straight to Finder when Civa has nothing else to offer.
                if library.contains(where: { !$0.isLinked(to: editor.record) }) { showsLibrary = true } else { isChoosing = true }
            }
        } header: {
            Text("Documents")
        } footer: {
            if editor.record is JobApplication {
                Text("The job posting, your cover letter, a transcript, or an offer letter, from your Documents or a new file. Drop files here too.")
            } else {
                Text("Certificates, project files, or portfolio pieces for this record, from your Documents or a new file. Drop files here too. They never change your profile by themselves.")
            }
        }
        .documentAdder(isChoosing: $isChoosing, add: addFiles)
        .sheet(isPresented: $showsLibrary) {
            DocumentLibraryPicker(
                excluded: Set(editor.record.documents.map(\.id)),
                onAttach: { documents in editor.update { record in documents.forEach { $0.attach(to: record) } } },
                onAddFiles: addFiles
            )
        }
    }

    private func addFiles(_ files: [DocumentFiles.Loaded]) {
        editor.update { record in DocumentFiles.insert(files, linkedTo: record, in: context) }
    }
}

/// Civa's own documents, to attach to a record without looking for the file again.
/// From Finder… adds a new file instead; dropping a file on the sheet does too.
struct DocumentLibraryPicker: View {
    /// Already on the record, so not offered.
    let excluded: Set<UUID>
    let onAttach: ([SupportingDocument]) -> Void
    let onAddFiles: ([DocumentFiles.Loaded]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var all: [SupportingDocument]
    @State private var selection: Set<UUID> = []
    @State private var query = ""
    @State private var isChoosing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Attach from Documents").font(.headline)
                Spacer()
                TextField("Search", text: $query, prompt: Text("Search"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding()
            Divider()
            if documents.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], alignment: .leading, spacing: 16) {
                        ForEach(documents) { tile($0) }
                    }
                    .padding()
                }
            }
            Divider()
            HStack {
                Button("From Finder…") { isChoosing = true }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(selection.count > 1 ? "Attach \(selection.count)" : "Attach") {
                    onAttach(all.filter { selection.contains($0.id) })
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding()
        }
        .frame(width: 640, height: 480)
        .documentAdder(isChoosing: $isChoosing) { files in
            onAddFiles(files)
            dismiss()
        }
    }

    private var documents: [SupportingDocument] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return all.filter { document in
            !excluded.contains(document.id)
                && (query.isEmpty || document.displayTitle.localizedCaseInsensitiveContains(query)
                    || document.kind.title.localizedCaseInsensitiveContains(query))
        }
        .sorted(by: SupportingDocument.galleryOrder)
    }

    private func tile(_ document: SupportingDocument) -> some View {
        let isSelected = selection.contains(document.id)
        return Button {
            if isSelected { selection.remove(document.id) } else { selection.insert(document.id) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                DocumentThumbnail(document: document, size: 120)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 3 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .tint)
                                .padding(6)
                        }
                    }
                Text(document.displayTitle)
                    .lineLimit(1)
                Text(document.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Library") {
    DocumentLibraryPicker(excluded: [], onAttach: { _ in }, onAddFiles: { _ in })
        .previewEnvironment()
}
