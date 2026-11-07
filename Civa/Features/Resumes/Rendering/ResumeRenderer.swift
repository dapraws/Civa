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
            let height = style.height(of: block.text)
            // ponytail: an entry taller than a whole page overflows; split it by line if that ever happens.
            if y + height > page.height - margin, y > margin {
                endPage()
                beginPage()
            }
            block.text.draw(
                with: CGRect(x: margin, y: y, width: style.width, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            if let link = block.link {
                // The context is flipped, and link rects are in page space, so flip the rect back.
                let top = y + link.top
                let rect = CGRect(x: margin, y: page.height - top - link.height, width: style.width, height: link.height)
                context.setURL(link.url as CFURL, for: rect)
            }
            y += height
        }
        endPage()
        context.closePDF()
        return data as Data
    }

    /// Text that moves to a new page as a whole, with an optional link over one line of it.
    private struct Block {
        let text: NSAttributedString
        var link: (url: URL, top: CGFloat, height: CGFloat)?
    }

    private static func blocks(for document: ResumeDocument, style: Style) -> [Block] {
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

        var blocks = header.length > 0 ? [Block(text: header)] : []
        for section in document.sections where !section.entries.isEmpty {
            for (index, entry) in section.entries.enumerated() {
                let text = NSMutableAttributedString()
                if index == 0 {
                    text.append(style.text(
                        section.title, scale: 1.1, bold: true, color: style.accent,
                        before: style.format.sectionSpacing, after: 3
                    ))
                }
                if section.kind == .skills {
                    text.append(skillLine(entry, style: style))
                    blocks.append(Block(text: text))
                    continue
                }
                let headingHeight = text.length > 0 ? style.height(of: text) : 0
                let title = titleLine(entry, kind: section.kind, style: style)
                text.append(title)
                text.append(detailLines(entry, kind: section.kind, style: style))
                var block = Block(text: text)
                if style.format.linksProof != false, let url = entry.proofURL.flatMap(URL.webLink) {
                    block.link = (url, headingHeight, style.height(of: title))
                }
                blocks.append(block)
            }
        }
        return blocks
    }

    /// "Bachelor of Computer Science, 3.86/4.00" on the left, the dates on the right.
    private static func titleLine(_ entry: ResumeEntry, kind: ResumeSection.Kind, style: Style) -> NSAttributedString {
        var title = entry.title
        if kind == .education, style.format.showsGrade != false, let grade = entry.grade, !grade.isBlank {
            title = [title, grade].filter { !$0.isBlank }.joined(separator: ", ")
        }
        let dates = entry.datesText(style.format.dateStyle ?? .short)
        return style.text(dates.isBlank ? title : "\(title)\t\(dates)", bold: true, before: 4, rightTab: style.width)
    }

    private static func detailLines(_ entry: ResumeEntry, kind: ResumeSection.Kind, style: Style) -> NSAttributedString {
        let lines = NSMutableAttributedString()
        var subtitle = [entry.subtitle]
        if style.format.showsEmploymentType == true { subtitle.append(entry.employmentType ?? "") }
        if style.format.showsWorkArrangement == true { subtitle.append(entry.workArrangement ?? "") }
        let subtitleText = subtitle.filter { !$0.isBlank }.joined(separator: " · ")
        if !subtitleText.isBlank {
            lines.append(style.text(subtitleText, italic: true, after: 1))
        }
        if kind == .education {
            if let thesis = entry.thesis, !thesis.isBlank {
                lines.append(labeled(String(localized: "Thesis"), thesis, style: style))
            }
            let coursework = (entry.coursework ?? []).filter { !$0.isBlank }
            if !coursework.isEmpty {
                lines.append(labeled(String(localized: "Relevant Coursework"), coursework.joined(separator: ", "), style: style))
            }
        }
        for bullet in entry.bullets where !bullet.isBlank {
            lines.append(style.text("•\t\(bullet)", after: 1, indent: 12))
        }
        return lines
    }

    /// "Thesis: On-device speech recognition", with the label in bold.
    private static func labeled(_ label: String, _ value: String, style: Style) -> NSAttributedString {
        let line = NSMutableAttributedString(string: "\(label): ", attributes: style.attributes(bold: true, after: 1))
        line.append(style.text(value, after: 1))
        return line
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

    func height(of text: NSAttributedString) -> CGFloat {
        ceil(text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height)
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
