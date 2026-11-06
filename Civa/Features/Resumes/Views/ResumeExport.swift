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

/// Export button: checks the resume, then saves the same PDF the preview shows (FR-050).
struct ResumeExportButton: View {
    let resume: Resume

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
                defaultFilename: resume.displayTitle
            ) { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
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
        let document = resume.document
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
}

#Preview {
    ResumeExportButton(resume: RecordEditor<Resume>.preview().record)
        .padding()
        .previewEnvironment()
}
