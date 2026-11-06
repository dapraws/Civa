//
//  ResumeRenderer.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit

/// Renders a resume to a text-based, single-column PDF (BR-001, FR-050). The editor previews
/// this same PDF, so the preview always matches the export (FR-033).
///
/// Layout is block by block: the header, then one block per entry, with a section heading
/// travelling with its first entry. A block that doesn't fit starts a new page, so an entry
/// is never split across pages.
enum ResumeRenderer {
    static func pdf(for document: ResumeDocument) -> Data {
        let format = document.format
        let page = format.paper.size
        let margin = format.margins.size
        let style = Style(format: format, width: page.width - 2 * margin)

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        let previous = NSGraphicsContext.current
        defer { NSGraphicsContext.current = previous }
        var y = margin

        func beginPage() {
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: page.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            y = margin
        }

        func endPage() {
            context.restoreGState()
            context.endPDFPage()
        }

        beginPage()
        for block in blocks(for: document, style: style) {
            let height = ceil(block.boundingRect(
                with: CGSize(width: style.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height)
            // ponytail: an entry taller than a whole page overflows; split it by line if that ever happens.
            if y + height > page.height - margin, y > margin {
                endPage()
                beginPage()
            }
            block.draw(
                with: CGRect(x: margin, y: y, width: style.width, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            y += height
        }
        endPage()
        context.closePDF()
        return data as Data
    }

    private static func blocks(for document: ResumeDocument, style: Style) -> [NSAttributedString] {
        let header = NSMutableAttributedString()
        let person = document.header
        if !person.fullName.isBlank {
            header.append(style.text(person.fullName, scale: 2, bold: true, color: style.accent, after: 2))
        }
        if !person.headline.isBlank {
            header.append(style.text(person.headline, scale: 1.1, after: 2))
        }
        let contact = ([person.location, person.email, person.phone] + person.links.map(\.url))
            .filter { !$0.isBlank }
            .joined(separator: " · ")
        if !contact.isEmpty {
            header.append(style.text(contact, scale: 0.95, color: .darkGray, after: 4))
        }
        if !document.summary.isBlank {
            header.append(style.text(document.summary, before: 6, after: 2))
        }

        var blocks = header.length > 0 ? [header as NSAttributedString] : []
        for section in document.sections where !section.entries.isEmpty {
            for (index, entry) in section.entries.enumerated() {
                let block = NSMutableAttributedString()
                if index == 0 {
                    block.append(style.text(
                        section.kind.heading, scale: 1.1, bold: true, color: style.accent,
                        before: style.format.sectionSpacing, after: 3
                    ))
                }
                block.append(section.kind == .skills ? skillLine(entry, style: style) : entryLines(entry, style: style))
                blocks.append(block)
            }
        }
        return blocks
    }

    private static func entryLines(_ entry: ResumeEntry, style: Style) -> NSAttributedString {
        let lines = NSMutableAttributedString()
        let titleLine = entry.dates.isBlank ? entry.title : "\(entry.title)\t\(entry.dates)"
        lines.append(style.text(titleLine, bold: true, before: 4, rightTab: style.width))
        if !entry.subtitle.isBlank {
            lines.append(style.text(entry.subtitle, italic: true, after: 1))
        }
        for bullet in entry.bullets where !bullet.isBlank {
            lines.append(style.text("•\t\(bullet)", after: 1, indent: 12))
        }
        return lines
    }

    /// "Languages: Swift, Kotlin", or just the skills when there's no category.
    private static func skillLine(_ entry: ResumeEntry, style: Style) -> NSAttributedString {
        let line = NSMutableAttributedString()
        if !entry.title.isBlank {
            line.append(NSAttributedString(string: "\(entry.title): ", attributes: style.attributes(bold: true)))
        }
        line.append(style.text(entry.subtitle, after: 1))
        return line
    }
}

private struct Style {
    let format: ResumeFormat
    let width: CGFloat

    var accent: NSColor {
        switch format.accent {
        case .black: .black
        case .navy: NSColor(srgbRed: 0.11, green: 0.20, blue: 0.40, alpha: 1)
        case .teal: NSColor(srgbRed: 0.04, green: 0.38, blue: 0.40, alpha: 1)
        case .burgundy: NSColor(srgbRed: 0.45, green: 0.10, blue: 0.18, alpha: 1)
        }
    }

    func font(scale: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }
        let size = format.fontSize * scale
        return NSFontManager.shared.font(withFamily: format.font.rawValue, traits: traits, weight: 5, size: size)
            ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    func attributes(
        scale: CGFloat = 1, bold: Bool = false, italic: Bool = false, color: NSColor = .black,
        before: CGFloat = 0, after: CGFloat = 0, indent: CGFloat = 0, rightTab: CGFloat? = nil
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = format.lineSpacing
        paragraph.paragraphSpacingBefore = before
        paragraph.paragraphSpacing = after
        paragraph.headIndent = indent
        paragraph.tabStops = [
            indent > 0 ? NSTextTab(textAlignment: .left, location: indent) : nil,
            rightTab.map { NSTextTab(textAlignment: .right, location: $0) },
        ].compactMap(\.self)
        return [.font: font(scale: scale, bold: bold, italic: italic), .foregroundColor: color, .paragraphStyle: paragraph]
    }

    /// One paragraph, ending in a newline.
    func text(
        _ string: String, scale: CGFloat = 1, bold: Bool = false, italic: Bool = false, color: NSColor = .black,
        before: CGFloat = 0, after: CGFloat = 0, indent: CGFloat = 0, rightTab: CGFloat? = nil
    ) -> NSAttributedString {
        NSAttributedString(string: string + "\n", attributes: attributes(
            scale: scale, bold: bold, italic: italic, color: color,
            before: before, after: after, indent: indent, rightTab: rightTab
        ))
    }
}
