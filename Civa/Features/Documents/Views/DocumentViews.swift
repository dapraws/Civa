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
            document.link(to: record)
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
/// edits to the record, saved or reverted with it.
struct DocumentsSection<Model: DocumentHolder>: View {
    let editor: RecordEditor<Model>

    @Environment(\.modelContext) private var context
    @State private var isChoosing = false

    var body: some View {
        Section {
            ForEach(editor.record.documents.sorted { $0.createdAt < $1.createdAt }) { document in
                DocumentRow(document: document) {
                    editor.update { _ in document.link(to: nil) }
                }
            }
            AddButton(title: String(localized: "Attach Document…")) { isChoosing = true }
        } header: {
            Text("Documents")
        } footer: {
            if editor.record is JobApplication {
                Text("The job posting, your cover letter, or an offer letter. Drop files here too.")
            } else {
                Text("Certificates, project files, or portfolio pieces for this record. Drop files here too. They never change your profile by themselves.")
            }
        }
        .documentAdder(isChoosing: $isChoosing) { files in
            editor.update { record in DocumentFiles.insert(files, linkedTo: record, in: context) }
        }
    }
}
