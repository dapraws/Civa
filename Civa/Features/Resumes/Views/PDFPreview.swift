//
//  PDFPreview.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftUI

/// Read-only view of a PDF. Keeps the scroll position when the PDF is replaced, so a live
/// preview doesn't jump on every edit.
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
        // Keep the exact scroll position, so typing or showing guides doesn't move the page.
        let clip = view.documentView?.enclosingScrollView?.contentView
        let origin = clip?.bounds.origin
        let hadDocument = view.document != nil
        view.document = document
        if hadDocument, let clip, let origin {
            view.layoutDocumentView()
            // Clamped, for a PDF that got shorter.
            clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: clip.bounds.size)).origin)
            clip.enclosingScrollView?.reflectScrolledClipView(clip)
        }
    }
}

#Preview {
    PDFPreview(data: ResumeRenderer.pdf(for: .blank))
        .frame(width: 400, height: 520)
}
