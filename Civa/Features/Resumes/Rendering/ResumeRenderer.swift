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
/// is never split across pages. Dividers and the proof check are drawn as shapes, never as
/// text, so applicant tracking systems read only the words.
enum ResumeRenderer {
    /// Red measurements drawn over the preview while spacing is adjusted. Never exported.
    enum Guide: CaseIterable {
        case margins, sectionSpacing, entrySpacing, lineSpacing
    }

    static func pdf(for document: ResumeDocument, guides: Set<Guide> = []) -> Data {
        let format = document.format
        let page = format.paper.size
        let margin = format.margins.size
        let side = format.sideMargin.size
        let style = Style(format: format, width: page.width - 2 * side)

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        let previous = NSGraphicsContext.current
        defer { NSGraphicsContext.current = previous }
        var y = margin
        // The gaps above sections and entries on this page, in page space from the top, for the guides.
        var gaps: [Gap] = []
        var firstLine: CGRect?
        var lineShown = false

        func beginPage() {
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: page.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            y = margin
            gaps = []
            firstLine = nil
        }

        func endPage() {
            if !guides.isEmpty {
                drawGuides(guides, in: context, style: style, page: page, gaps: gaps, firstLine: firstLine)
            }
            context.restoreGState()
            context.endPDFPage()
        }

        beginPage()
        for block in blocks(for: document, style: style) {
            // Without the final line break: text layout turns it into an empty extra line,
            // which added about a line of hidden space under every block.
            let text = block.text.droppingFinalLineBreak
            let height = style.height(of: text)
            // The space above is added here, not as paragraph spacing: text drawing ignores
            // spacing before the first line it draws. None at the top of a page.
            var gap = y > margin ? block.spacingBefore : 0
            // ponytail: an entry taller than a whole page overflows; split it by line if that ever happens.
            if y + gap + height > page.height - margin, y > margin {
                endPage()
                beginPage()
                gap = 0
            }
            if gap > 0 {
                gaps.append(Gap(guide: block.startsWithHeading ? .sectionSpacing : .entrySpacing, top: y, bottom: y + gap))
            }
            y += gap
            if let line = block.firstLine, !lineShown {
                firstLine = line.offsetBy(dx: side, dy: y)
                lineShown = true
            }
            text.draw(
                with: CGRect(x: side, y: y, width: style.width, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            for rule in block.rules {
                context.setStrokeColor(style.accent.cgColor)
                context.setLineWidth(format.dividerWidth)
                context.move(to: CGPoint(x: side, y: y + rule))
                context.addLine(to: CGPoint(x: side + style.width, y: y + rule))
                context.strokePath()
            }
            if let mark = block.mark {
                drawCheck(in: context, at: CGPoint(x: side + mark.x, y: y + mark.y), size: style.format.fontSize * 0.7)
            }
            if let link = block.link {
                // The context is flipped, and link rects are in page space, so flip the rect back.
                let top = y + link.top
                let rect = CGRect(x: side, y: page.height - top - link.height, width: style.width, height: link.height)
                context.setURL(link.url as CFURL, for: rect)
            }
            y += height
        }
        endPage()
        context.closePDF()
        return data as Data
    }

    /// A small gray check, the proof mark: a shape, so text extraction never sees it.
    private static func drawCheck(in context: CGContext, at center: CGPoint, size: CGFloat) {
        let half = size / 2
        context.saveGState()
        context.setStrokeColor(NSColor(white: 0.45, alpha: 1).cgColor)
        context.setLineWidth(max(0.8, size * 0.12))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addEllipse(in: CGRect(x: center.x - half, y: center.y - half, width: size, height: size))
        context.strokePath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y + half * 0.02))
        context.addLine(to: CGPoint(x: center.x - half * 0.1, y: center.y + half * 0.38))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.35))
        context.strokePath()
        context.restoreGState()
    }

    /// Text that moves to a new page as a whole, with what's drawn over it. Offsets are from
    /// the block's top-left.
    private struct Block {
        let text: NSAttributedString
        var link: (url: URL, top: CGFloat, height: CGFloat)?
        /// Rules under headings, by their distance from the block's top.
        var rules: [CGFloat] = []
        /// The center of the proof check.
        var mark: CGPoint?
        /// Whether a section heading opens the block, with the section spacing above it.
        var startsWithHeading = false
        /// Space above the block, unless it starts a page.
        var spacingBefore: CGFloat = 0
        /// The entry's first line, for the line spacing guide.
        var firstLine: CGRect?
    }

    private struct Gap {
        let guide: Guide
        let top: CGFloat
        let bottom: CGFloat
    }

    // MARK: - Guides

    private static let guideColor = NSColor(srgbRed: 0.93, green: 0.22, blue: 0.27, alpha: 1)

    private static func drawGuides(
        _ guides: Set<Guide>, in context: CGContext, style: Style, page: CGSize, gaps: [Gap], firstLine: CGRect?
    ) {
        let format = style.format
        let margin = format.margins.size
        let side = format.sideMargin.size
        context.saveGState()
        context.setStrokeColor(guideColor.cgColor)
        if guides.contains(.margins) {
            let content = CGRect(x: side, y: margin, width: page.width - 2 * side, height: page.height - 2 * margin)
            context.setLineWidth(0.6)
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.stroke(content)
            context.setLineDash(phase: 0, lengths: [])
            verticalBeam(in: context, x: page.width / 2, from: 0, to: margin)
            pill(String(localized: "Top \(format.margins.inches)"), leading: CGPoint(x: page.width / 2 + 6, y: margin / 2))
            // In the bottom margin, where it can't cover text or the section guides.
            let y = page.height - margin / 2
            horizontalBeam(in: context, y: y, from: 0, to: side)
            pill(String(localized: "Side \(format.sideMargin.inches)"), leading: CGPoint(x: side + 4, y: y))
        }
        for gap in gaps where guides.contains(gap.guide) {
            // Sections on the left, entries on the right, so both can show at once.
            let isSection = gap.guide == .sectionSpacing
            context.setStrokeColor(guideColor.withAlphaComponent(0.35).cgColor)
            context.setLineWidth(0.5)
            for line in [gap.top, gap.bottom] {
                context.move(to: CGPoint(x: side, y: line))
                context.addLine(to: CGPoint(x: page.width - side, y: line))
            }
            context.strokePath()
            context.setStrokeColor(guideColor.cgColor)
            let x = isSection ? side - 5 : page.width - side + 5
            verticalBeam(in: context, x: x, from: gap.top, to: gap.bottom)
            let label = "\(points(gap.bottom - gap.top)) pt"
            if isSection {
                pill(label, trailing: CGPoint(x: x - 4, y: (gap.top + gap.bottom) / 2))
            } else {
                pill(label, leading: CGPoint(x: x + 4, y: (gap.top + gap.bottom) / 2))
            }
        }
        if guides.contains(.lineSpacing), let line = firstLine {
            // Left margin, two short lines, so it fits even narrow margins.
            context.setStrokeColor(guideColor.cgColor)
            let x = side - 5
            verticalBeam(in: context, x: x, from: line.minY, to: line.maxY)
            pill("\(format.lineSpacingTitle)×\n\(points(line.height)) pt", trailing: CGPoint(x: x - 4, y: line.midY))
        }
        context.restoreGState()
    }

    /// "10" or "13.8".
    private static func points(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    /// A red I-beam: a line with a tick at each end.
    private static func verticalBeam(in context: CGContext, x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: x, y: top))
        context.addLine(to: CGPoint(x: x, y: bottom))
        for end in [top, bottom] {
            context.move(to: CGPoint(x: x - 2.5, y: end))
            context.addLine(to: CGPoint(x: x + 2.5, y: end))
        }
        context.strokePath()
    }

    private static func horizontalBeam(in context: CGContext, y: CGFloat, from left: CGFloat, to right: CGFloat) {
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: left, y: y))
        context.addLine(to: CGPoint(x: right, y: y))
        for end in [left, right] {
            context.move(to: CGPoint(x: end, y: y - 2.5))
            context.addLine(to: CGPoint(x: end, y: y + 2.5))
        }
        context.strokePath()
    }

    /// A red label like "10 pt", placed by its center, its trailing edge, or its leading edge.
    private static func pill(_ text: String, center: CGPoint? = nil, trailing: CGPoint? = nil, leading: CGPoint? = nil) {
        let label = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 6.5, weight: .bold), .foregroundColor: NSColor.white,
        ])
        let size = label.size()
        let box = CGSize(width: size.width + 6, height: size.height + 2)
        let origin: CGPoint = if let center {
            CGPoint(x: center.x - box.width / 2, y: center.y - box.height / 2)
        } else if let trailing {
            CGPoint(x: trailing.x - box.width, y: trailing.y - box.height / 2)
        } else {
            CGPoint(x: leading?.x ?? 0, y: (leading?.y ?? 0) - box.height / 2)
        }
        let rect = CGRect(origin: origin, size: box)
        guideColor.setFill()
        let radius = min(box.height, 9) / 2
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        label.draw(at: CGPoint(x: rect.minX + 3, y: rect.minY + 1))
    }

    private static func blocks(for document: ResumeDocument, style: Style) -> [Block] {
        let template = style.format.layout
        let header = NSMutableAttributedString()
        let person = document.header.printed
        let alignment: NSTextAlignment = template == .classic ? .left : .center
        var nameRange: NSRange?
        if !person.fullName.isBlank {
            let start = header.length
            let name = template == .tech
                ? style.smallCaps(person.fullName, scale: 2.2, bold: true, color: style.accent, alignment: alignment, after: 2)
                : style.text(
                    person.fullName, scale: template.nameScale, bold: true, color: style.accent,
                    after: template == .harvard ? 6 + style.format.dividerWidth : 2, alignment: alignment
                )
            header.append(name)
            nameRange = NSRange(location: start, length: (person.fullName as NSString).length)
        }
        if !person.headline.isBlank {
            // Never larger than the name: Harvard sets the name at body size.
            header.append(style.text(person.headline, scale: min(1.1, template.nameScale), after: 2, alignment: alignment))
        }
        let contact = ([person.location, person.email, person.phone] + person.links.map(\.url))
            .filter { !$0.isBlank }
            .joined(separator: template == .tech ? " | " : template == .harvard ? " • " : " · ")
        if !contact.isEmpty {
            header.append(style.text(contact, scale: 0.95, color: template == .harvard ? .black : .darkGray, after: 2, alignment: alignment))
        }
        let summaryHasHeading = style.format.showsSummaryHeading == true
        let summary = document.printedSummary
        if !summary.isBlank, !summaryHasHeading {
            // Part of the header block: same alignment, right under the contact line.
            header.append(style.text(summary, before: 2, after: 2, alignment: alignment))
        }

        var blocks: [Block] = []
        if header.length > 0 {
            // No rule under the header: the first heading's rule follows right after, as in the
            // MIT and Jake's samples. Harvard's template rules off the name instead.
            var block = Block(text: header)
            if template == .harvard, let nameRange {
                block.rules = [style.lineRect(of: nameRange, in: header).maxY + 2 + style.format.dividerWidth / 2]
            }
            blocks.append(block)
        }
        if !summary.isBlank, summaryHasHeading {
            let text = NSMutableAttributedString()
            let headingRange = style.appendHeading(String(localized: "Summary"), to: text)
            text.append(style.text(summary, after: 2))
            blocks.append(Block(
                text: text, rules: style.dividerOffsets(headingRange, in: text), startsWithHeading: true,
                spacingBefore: style.format.sectionSpacing
            ))
        }

        for section in document.sections where !section.entries.isEmpty {
            for (index, entry) in section.entries.enumerated() {
                let text = NSMutableAttributedString()
                var rules: [CGFloat] = []
                if index == 0 {
                    let headingRange = style.appendHeading(section.title, to: text)
                    rules = style.dividerOffsets(headingRange, in: text)
                }
                // Skill lines sit tight; entries take the entry spacing.
                let spacing = index == 0 ? style.format.sectionSpacing : section.kind == .skills ? 0 : style.format.entryGap
                if section.kind == .skills {
                    text.append(skillLine(entry, style: style))
                    blocks.append(Block(text: text, rules: rules, startsWithHeading: index == 0, spacingBefore: spacing))
                    continue
                }
                let entryStart = text.length
                let titleRange = appendEntry(entry, kind: section.kind, to: text, style: style)
                var block = Block(text: text, rules: rules, startsWithHeading: index == 0, spacingBefore: spacing)
                block.firstLine = style.lineRect(of: NSRange(location: entryStart, length: 1), in: text)
                // Link Proof shows the check and makes the title open the proof.
                if let url = entry.proofLink(style.format) {
                    let line = style.lineRect(of: titleRange, in: text)
                    block.link = (url, line.minY, line.height)
                    let end = style.glyphRect(of: NSRange(location: NSMaxRange(titleRange) - 1, length: 1), in: text)
                    block.mark = CGPoint(x: end.maxX + style.format.fontSize * 0.65, y: end.midY)
                }
                blocks.append(block)
            }
        }
        return blocks
    }

    /// The entry's lines, in the template's order. Returns the range of the title text, where
    /// the proof check goes.
    private static func appendEntry(
        _ entry: ResumeEntry, kind: ResumeSection.Kind, to text: NSMutableAttributedString, style: Style
    ) -> NSRange {
        let format = style.format
        var title = entry.title
        if kind == .education, entry.shows(.grade, in: format), let grade = entry.grade, !grade.isBlank {
            title = [title, grade].filter { !$0.isBlank }.joined(separator: ", ")
        }
        let dates = entry.shows(.dates, in: format) ? entry.datesText(format.dateStyle ?? .short) : ""
        let details = [
            entry.shows(.employmentType, in: format) ? entry.employmentType ?? "" : "",
            entry.shows(.workArrangement, in: format) ? entry.workArrangement ?? "" : "",
        ].filter { !$0.isBlank }
        let organization = entry.organization
        let organizationFirst = [.experience, .organizational, .education].contains(kind)
            && format.layout != .classic && !organization.isBlank

        let titleRange: NSRange
        if organizationFirst {
            let location = entry.shows(.location, in: format) ? entry.location ?? "" : ""
            let titleText = ([title] + details).filter { !$0.isBlank }.joined(separator: " · ")
            // MIT and Harvard: organization … location, then title … dates. Tech: organization …
            // dates, then title … location.
            let (right1, right2) = format.layout == .tech ? (dates, location) : (location, dates)
            // Harvard sets the role in bold and the degree plain, with location and dates plain on
            // the right; the others set the role in italics.
            let isHarvard = format.layout == .harvard
            text.append(style.plainRight(style.text(tabbed(organization, right1), bold: true, rightTab: style.width), right1, when: isHarvard))
            let start = text.length
            let titleLine = style.text(tabbed(titleText, right2), bold: isHarvard && kind != .education, italic: !isHarvard, after: 1, rightTab: style.width)
            text.append(style.plainRight(titleLine, right2, when: isHarvard))
            titleRange = NSRange(location: start, length: (titleText as NSString).length)
        } else {
            let start = text.length
            text.append(style.text(tabbed(title, dates), bold: true, rightTab: style.width))
            titleRange = NSRange(location: start, length: max(1, (title as NSString).length))
            // A hidden location comes off the end of the subtitle too.
            let subtitle = ([entry.shows(.location, in: format) ? entry.subtitle : organization] + details).filter { !$0.isBlank }.joined(separator: " · ")
            if !subtitle.isBlank {
                text.append(style.text(subtitle, italic: true, after: 1))
            }
        }
        if kind == .education {
            if entry.shows(.thesis, in: format), let thesis = entry.thesis, !thesis.isBlank {
                text.append(labeled(String(localized: "Thesis"), thesis, style: style))
            }
            let coursework = entry.shows(.coursework, in: format) ? (entry.coursework ?? []).filter { !$0.isBlank } : []
            if !coursework.isEmpty {
                text.append(labeled(String(localized: "Relevant Coursework"), coursework.joined(separator: ", "), style: style))
            }
        }
        for bullet in entry.bullets where !bullet.isBlank {
            text.append(style.text("•\t\(bullet)", after: 1, indent: 12))
        }
        // Room for the proof check after the title, without adding a character.
        if entry.proofLink(format) != nil, titleRange.length > 0 {
            text.addAttribute(.kern, value: format.fontSize * 1.1, range: NSRange(location: NSMaxRange(titleRange) - 1, length: 1))
        }
        return titleRange
    }

    /// "Left\tRight" when there's something on the right.
    private static func tabbed(_ left: String, _ right: String) -> String {
        right.isBlank ? left : "\(left)\t\(right)"
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

private extension NSAttributedString {
    var droppingFinalLineBreak: NSAttributedString {
        guard string.hasSuffix("\n") else { return self }
        return attributedSubstring(from: NSRange(location: 0, length: length - 1))
    }
}

nonisolated extension ResumeEntry {
    /// The proof to link and mark, when the resume links proof.
    func proofLink(_ format: ResumeFormat) -> URL? {
        format.linksProof == false || !shows(.proof, in: format) ? nil : proofURL.flatMap(URL.webLink)
    }

    /// The subtitle without the location at its end: "Gojek" from "Gojek · Jakarta, Indonesia".
    var organization: String {
        guard let location, !location.isBlank else { return subtitle }
        for separator in [" · ", ", "] where subtitle.hasSuffix(separator + location) {
            return String(subtitle.dropLast((separator + location).count))
        }
        return subtitle == location ? "" : subtitle
    }
}

extension ResumeFormat {
    /// "Single" for 1.0, else "1.15".
    var lineSpacingName: String {
        lineSpacing == 1 ? String(localized: "Single") : lineSpacingTitle
    }

    /// "1.15", whatever the Mac's language.
    var lineSpacingTitle: String {
        String(format: "%.2f", lineSpacing).replacingOccurrences(of: "(\\.\\d)0$", with: "$1", options: .regularExpression)
    }
}

extension ResumeFormat.Margins {
    /// "0.75 in".
    var inches: String {
        switch self {
        case .narrow: "0.5 in"
        case .normal: "0.75 in"
        case .wide: "1 in"
        }
    }
}

private extension ResumeFormat.Template {
    var nameScale: CGFloat {
        switch self {
        case .classic: 2
        case .mit: 1.6
        // Harvard's template sets the name at body size, bold, over a rule.
        case .harvard: 1
        case .tech: 2.2
        }
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

    /// Lays the text out the way `draw(with:options:)` does, for measuring parts of it. The
    /// storage is returned too: a layout manager doesn't keep its text alive.
    private func layout(_ text: NSAttributedString) -> (NSTextStorage, NSLayoutManager, NSTextContainer) {
        let storage = NSTextStorage(attributedString: text)
        let manager = NSLayoutManager()
        manager.usesFontLeading = true
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return (storage, manager, container)
    }

    /// The lines holding `range`, without paragraph spacing.
    func lineRect(of range: NSRange, in text: NSAttributedString) -> CGRect {
        let (storage, manager, _) = layout(text)
        defer { withExtendedLifetime(storage) {} }
        let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = CGRect.null
        manager.enumerateLineFragments(forGlyphRange: glyphs) { _, used, _, _, _ in rect = rect.union(used) }
        return rect.isNull ? .zero : rect
    }

    /// Where the glyphs of `range` sit.
    func glyphRect(of range: NSRange, in text: NSAttributedString) -> CGRect {
        let (storage, manager, container) = layout(text)
        defer { withExtendedLifetime(storage) {} }
        let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = manager.boundingRect(forGlyphRange: glyphs, in: container)
        // The kern after the last glyph widens its rect; measure the glyph alone.
        if let kern = text.attribute(.kern, at: range.location, effectiveRange: nil) as? CGFloat { rect.size.width -= kern }
        return rect
    }

    /// The line with the text after its tab set in the regular weight.
    func plainRight(_ line: NSAttributedString, _ right: String, when condition: Bool) -> NSAttributedString {
        guard condition, !right.isBlank else { return line }
        let result = NSMutableAttributedString(attributedString: line)
        let length = (right as NSString).length
        result.addAttribute(.font, value: font(scale: 1, bold: false, italic: false), range: NSRange(location: result.length - 1 - length, length: length))
        return result
    }

    /// A section heading in the template's style. Returns its range.
    func appendHeading(_ title: String, to text: NSMutableAttributedString) -> NSRange {
        let start = text.length
        // The section spacing above is added by the layout; this is the room below, before the first entry.
        let before: CGFloat = 0
        let after: CGFloat = format.dividers ? 6 + format.dividerWidth : 5
        switch format.layout {
        case .classic:
            text.append(self.text(title, scale: 1.1, bold: true, color: accent, before: before, after: after))
        case .mit:
            text.append(self.text(title.uppercased(), bold: true, color: accent, before: before, after: after))
        case .harvard:
            text.append(self.text(title, scale: 1.05, bold: true, color: accent, before: before, after: after, alignment: .center))
        case .tech:
            text.append(smallCaps(title, scale: 1.15, bold: false, color: accent, alignment: .left, before: before, after: after))
        }
        return NSRange(location: start, length: text.length - start)
    }

    /// A rule under the heading at `range`, when the resume shows dividers.
    func dividerOffsets(_ range: NSRange, in text: NSAttributedString) -> [CGFloat] {
        format.dividers ? [lineRect(of: range, in: text).maxY + 2 + format.dividerWidth / 2] : []
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
        before: CGFloat = 0, after: CGFloat = 0, indent: CGFloat = 0, rightTab: CGFloat? = nil,
        alignment: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = format.lineSpacing
        paragraph.paragraphSpacingBefore = before
        paragraph.paragraphSpacing = after
        paragraph.headIndent = indent
        paragraph.alignment = alignment
        paragraph.tabStops = [
            indent > 0 ? NSTextTab(textAlignment: .left, location: indent) : nil,
            rightTab.map { NSTextTab(textAlignment: .right, location: $0) },
        ].compactMap(\.self)
        return [.font: font(scale: scale, bold: bold, italic: italic), .foregroundColor: color, .paragraphStyle: paragraph]
    }

    /// One paragraph, ending in a newline.
    func text(
        _ string: String, scale: CGFloat = 1, bold: Bool = false, italic: Bool = false, color: NSColor = .black,
        before: CGFloat = 0, after: CGFloat = 0, indent: CGFloat = 0, rightTab: CGFloat? = nil,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        NSAttributedString(string: string + "\n", attributes: attributes(
            scale: scale, bold: bold, italic: italic, color: color,
            before: before, after: after, indent: indent, rightTab: rightTab, alignment: alignment
        ))
    }

    /// Small capitals, as LaTeX sets them: real capitals, with the lowercase letters as smaller
    /// capitals. Extracted text reads as plain capitals.
    func smallCaps(
        _ string: String, scale: CGFloat, bold: Bool, color: NSColor, alignment: NSTextAlignment,
        before: CGFloat = 0, after: CGFloat = 0
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for character in string {
            let isLower = character.isLowercase
            result.append(NSAttributedString(
                string: String(character).uppercased(),
                attributes: attributes(
                    scale: isLower ? scale * 0.8 : scale, bold: bold, color: color,
                    before: before, after: after, alignment: alignment
                )
            ))
        }
        result.append(NSAttributedString(string: "\n", attributes: attributes(scale: scale, bold: bold, color: color, before: before, after: after, alignment: alignment)))
        return result
    }
}
