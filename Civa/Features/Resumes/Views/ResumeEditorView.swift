//
//  ResumeEditorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftUI

/// Outline, fields, and live preview, with draggable dividers between them (FR-032, FR-033).
struct ResumeEditorView: View {
    let editor: RecordEditor<Resume>
    @State private var selection: ResumeOutlineItem?
    @State private var outlineWidth: CGFloat = 210
    @State private var previewWidth: CGFloat = 540

    init(editor: RecordEditor<Resume>) {
        self.editor = editor
        // A new resume starts on its name, which it needs before it can be saved.
        _selection = State(initialValue: editor.isNew ? .info : .header)
    }

    var body: some View {
        let document = editor.binding(\.document)
        GeometryReader { proxy in
            // The fields column takes what's left and keeps at least 280 pt.
            let previewRange = 280...max(280, proxy.size.width - outlineWidth - 282)
            HStack(spacing: 0) {
                ResumeOutlineView(document: document, selection: $selection)
                    .frame(width: outlineWidth)
                ColumnDivider(width: $outlineWidth, range: 170...340, direction: 1)
                ResumeItemForm(editor: editor, document: document, selection: $selection)
                    .frame(maxWidth: .infinity)
                ColumnDivider(width: $previewWidth, range: previewRange, direction: -1)
                ResumePreviewPane(document: document)
                    .frame(width: min(max(previewWidth, previewRange.lowerBound), previewRange.upperBound))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ResumeExportButton(resume: editor.record)
            }
        }
    }
}

/// The PDF preview with the format bar on top.
private struct ResumePreviewPane: View {
    @Binding var document: ResumeDocument

    var body: some View {
        let data = ResumeRenderer.pdf(for: document)
        VStack(spacing: 0) {
            ResumeFormatBar(format: $document.format, pageCount: PDFDocument(data: data)?.pageCount ?? 0)
            Divider()
            PDFPreview(data: data)
        }
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1100, height: 700)
        .previewEnvironment()
}
