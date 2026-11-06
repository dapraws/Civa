//
//  ResumeExport.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The PDF handed to the save dialog.
nonisolated struct PDFFile: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Export button: saves unsaved changes, checks the resume, then writes the same PDF the preview
/// shows (FR-050). Each export is recorded in the resume's history (FR-043).
struct ResumeExportButton: View {
    let editor: RecordEditor<Resume>

    @Environment(\.modelContext) private var context
    @State private var file: PDFFile?
    @State private var issues: [String] = []
    @State private var isReviewingIssues = false
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        Button("Export PDF…", systemImage: "square.and.arrow.up", action: check)
            .keyboardShortcut("e")
            .help("Export as PDF (⌘E)")
            .alert("Check Your Resume", isPresented: $isReviewingIssues) {
                Button("Export Anyway") { isExporting = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(issues.map { "• \($0)" }.joined(separator: "\n"))
            }
            .fileExporter(
                isPresented: $isExporting,
                document: file,
                contentType: .pdf,
                defaultFilename: editor.record.displayTitle
            ) { result in
                switch result {
                case .success: recordExport()
                case .failure(let error): exportError = error.localizedDescription
                }
            }
            .alert(
                "Civa Couldn't Export the PDF",
                isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(exportError ?? "")
            }
    }

    private func check() {
        // The exported version goes into History, which holds saved versions only.
        if editor.isDirty, !editor.save() {
            exportError = editor.storeError ?? String(localized: "Fix the highlighted fields, then export again.")
            editor.storeError = nil
            return
        }
        let document = editor.record.document
        let data = ResumeRenderer.pdf(for: document)
        file = PDFFile(data: data)
        issues = ResumeCheck.issues(
            for: document,
            pageCount: PDFDocument(data: data)?.pageCount ?? 0,
            unconfirmedSources: ResumeCheck.unconfirmedSources(in: context)
        )
        if issues.isEmpty {
            isExporting = true
        } else {
            isReviewingIssues = true
        }
    }

    private func recordExport() {
        guard editor.record.recordSnapshot(.exported, in: context) != nil, !editor.isDirty else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            exportError = String(localized: "The PDF was exported, but Civa couldn't add it to History.")
        }
    }
}

#Preview {
    ResumeExportButton(editor: RecordEditor<Resume>.preview())
        .padding()
        .previewEnvironment()
}
