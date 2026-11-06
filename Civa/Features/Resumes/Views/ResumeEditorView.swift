//
//  ResumeEditorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftUI

/// Form on the left in the same order as the page, live preview on the right (FR-032, FR-033).
/// Format options live with the preview; resume info that never prints lives in the toolbar.
struct ResumeEditorView: View {
    let editor: RecordEditor<Resume>

    @State private var isShowingInfo = false
    @State private var isReordering = false

    var body: some View {
        let document = editor.binding(\.document)
        // A plain stack: a split view nested in the list/detail split overflows under the list.
        HStack(spacing: 0) {
            Form {
                if editor.error(for: \.title) != nil {
                    Section {
                        FieldError(editor.error(for: \.title))
                        Button("Open Resume Info") { isShowingInfo = true }
                    }
                }
                ResumeSectionsForm(document: document)
            }
            .formStyle(.grouped)
            .frame(minWidth: 340, maxWidth: .infinity)

            Divider()

            ResumePreviewPane(document: document)
                .frame(minWidth: 240, maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Resume Info", systemImage: "info.circle") { isShowingInfo = true }
                    .help("Name, target position, and job description")
                    .popover(isPresented: $isShowingInfo, arrowEdge: .bottom) {
                        ResumeInfoForm(editor: editor)
                    }
                Button("Reorder Sections", systemImage: "arrow.up.arrow.down") { isReordering = true }
                    .help("Change the order of sections")
                ResumeExportButton(resume: editor.record)
            }
        }
        .sheet(isPresented: $isReordering) {
            ReorderSectionsSheet(sections: document.sections)
        }
    }
}

/// The PDF preview with a format bar on top.
private struct ResumePreviewPane: View {
    @Binding var document: ResumeDocument
    @State private var isFormatting = false

    var body: some View {
        let data = ResumeRenderer.pdf(for: document)
        let pages = PDFDocument(data: data)?.pageCount ?? 0
        VStack(spacing: 0) {
            HStack {
                Text(summary(pages: pages))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Format", systemImage: "textformat") { isFormatting = true }
                    .popover(isPresented: $isFormatting, arrowEdge: .bottom) {
                        Form {
                            ResumeFormatForm(format: $document.format)
                        }
                        .formStyle(.grouped)
                        .frame(width: 380, height: 420)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            PDFPreview(data: data)
        }
    }

    private func summary(pages: Int) -> String {
        let format = document.format
        let paper = format.paper == .a4 ? "A4" : "Letter"
        let size = "\(format.fontSize.formatted()) pt"
        let pageCount = String(AttributedString(localized: "^[\(pages) page](inflect: true)").characters)
        return [pageCount, paper, size, format.font.rawValue].joined(separator: " · ")
    }
}

/// Resume details that don't print: its name, target position, and job description.
private struct ResumeInfoForm: View {
    let editor: RecordEditor<Resume>

    var body: some View {
        Form {
            Section {
                TextField("Resume Name", text: editor.binding(\.title), prompt: Text("Required"))
                FieldError(editor.error(for: \.title))
                TextField("Target Position", text: editor.binding(\.targetPosition), prompt: Text("iOS Developer"))
            } footer: {
                Text("Only you see these. They don't appear on the resume.")
            }
            Section("Job Description") {
                TextField(
                    "Job Description",
                    text: editor.binding(\.jobDescription),
                    prompt: Text("Paste the job description for this version"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(6...14)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }
}

/// Drag sections into the order they should appear on the page (FR-036).
private struct ReorderSectionsSheet: View {
    @Binding var sections: [ResumeSection]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reorder Sections")
                .font(.headline)
            Text("Drag sections into the order they should appear. Your name and summary always come first.")
                .foregroundStyle(.secondary)
            List {
                ForEach(sections) { section in
                    Label(section.kind.heading, systemImage: "line.3.horizontal")
                }
                .onMove { sections.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 220)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1000, height: 700)
        .previewEnvironment()
}
