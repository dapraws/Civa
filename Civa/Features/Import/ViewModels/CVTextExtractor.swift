//
//  CVTextExtractor.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Reads the text of a PDF or Word CV with built-in frameworks. Never writes to the file (FR-020).
enum CVTextExtractor {
    enum Failure: LocalizedError {
        case unsupported, unreadable, noText

        var errorDescription: String? {
            switch self {
            case .unsupported: String(localized: "Civa can import PDF and Word (.docx) files.")
            case .unreadable: String(localized: "Civa couldn't open this file. It may be damaged or password protected.")
            case .noText: String(localized: "This file has no selectable text. It may be a scan or an image.")
            }
        }
    }

    static let docx = UTType("org.openxmlformats.wordprocessingml.document") ?? .data
    static let contentTypes: [UTType] = [.pdf, docx]

    /// The text to show and what was found in it. LinkedIn's own PDF is read by its layout;
    /// anything else goes through the general CV rules.
    static func read(from url: URL) throws -> (text: String, draft: ImportDraft) {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true,
           let document = PDFDocument(url: url), !document.isLocked {
            let lines = LinkedInPDF.lines(of: document)
            if LinkedInPDF.isLinkedIn(lines) {
                return (LinkedInPDF.text(of: lines).precomposedStringWithCompatibilityMapping, LinkedInPDF.draft(from: lines))
            }
        }
        let text = try text(from: url)
        return (text, CVParser.parse(text))
    }

    static func text(from url: URL) throws -> String {
        let type = UTType(filenameExtension: url.pathExtension)
        let text: String
        if type?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url), !document.isLocked else { throw Failure.unreadable }
            text = lines(of: document)
        } else if type?.conforms(to: docx) == true {
            guard let string = try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            ) else { throw Failure.unreadable }
            text = string.string
        } else {
            throw Failure.unsupported
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.noText }
        // Ligatures such as "ﬀ" become plain letters.
        return text.precomposedStringWithCompatibilityMapping
    }

    /// Text rebuilt row by row from where each character sits on the page. PDFKit's own text
    /// (and its line grouping) splits a row wherever glyphs are drawn separately, so a title and
    /// its right-aligned dates, or a "·" between two words, come out on different lines.
    private static func lines(of document: PDFDocument) -> String {
        (0..<document.pageCount).compactMap { document.page(at: $0) }.flatMap(rows).joined(separator: "\n")
    }

    /// PDFKit's line pieces, merged into rows by their position on the page.
    static func rows(of page: PDFPage) -> [String] {
        let pieces = (page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine() ?? [])
            .compactMap { selection -> (text: String, bounds: CGRect)? in
                guard let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return (text, selection.bounds(for: page))
            }

        // A piece joins a row whose vertical middle is within half a line of its own.
        var rows: [[(text: String, bounds: CGRect)]] = []
        for piece in pieces {
            if let row = rows.firstIndex(where: { row in
                let reference = row[0].bounds
                return abs(reference.midY - piece.bounds.midY) < max(reference.height, piece.bounds.height) / 2
            }) {
                rows[row].append(piece)
            } else {
                rows.append([piece])
            }
        }
        return rows
            .sorted { $0[0].bounds.midY > $1[0].bounds.midY }
            .map { $0.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: " ") }
    }
}
