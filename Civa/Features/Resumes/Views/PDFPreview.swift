//
//  PDFPreview.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftUI

/// Read-only view of a PDF. Keeps the visible page when the PDF is replaced, so a live
/// preview doesn't jump back to page 1 on every edit.
struct PDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        return view
    }

    /// PDFView asks for a full page of width; take whatever space the layout offers instead.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PDFView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: proposal.height ?? 400)
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document?.dataRepresentation() != data, let document = PDFDocument(data: data) else { return }
        let pageIndex = view.currentPage.flatMap { view.document?.index(for: $0) } ?? 0
        view.document = document
        if let page = document.page(at: min(pageIndex, document.pageCount - 1)) {
            view.go(to: page)
        }
    }
}

#Preview {
    PDFPreview(data: ResumeRenderer.pdf(for: .blank))
        .frame(width: 400, height: 520)
}
