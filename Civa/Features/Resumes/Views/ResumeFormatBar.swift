//
//  ResumeFormatBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import TipKit

/// A Word-style ribbon across the top of the resume editor: grouped controls with a caption
/// under each group and a line between groups. Everything stays visible; when the window is
/// narrow the groups wrap onto a second row. Hovering a spacing control shows its distance on
/// the preview. Options are limited so the resume stays single-column and ATS-friendly (FR-036).
struct ResumeFormatBar: View {
    @Binding var format: ResumeFormat
    let pageCount: Int
    /// Keeps every distance guide on.
    @Binding var showsGuides: Bool
    /// The pointer entered (true) or left (false) a spacing control.
    var onHoverGuide: (ResumeRenderer.Guide, Bool) -> Void = { _, _ in }
    /// The ribbon tip first, then Proof Check, one at a time.
    @State private var tips = TipGroup(.ordered) {
        CivaTip.ribbon
        CivaTip.proof
    }

    /// The tip, while it's the group's turn.
    private func currentTip(_ tip: CivaTip) -> CivaTip? {
        (tips.currentTip as? CivaTip)?.id == tip.id ? tip : nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            FlowLayout(spacing: 0, rowSpacing: 4) {
                RibbonGroup("Template") {
                    RibbonPicker("Template", selection: Binding(get: { format.layout }, set: { format.apply($0) }), value: format.layout.title) {
                        ForEach(ResumeFormat.Template.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .help("Template: sets the layout, and a font you can still change")
                    .popoverTip(currentTip(CivaTip.ribbon), arrowEdge: .top)
                }
                RibbonGroup("Font") {
                    RibbonPicker("Font", selection: $format.font, value: format.font.rawValue) {
                        ForEach(ResumeFormat.Font.allCases, id: \.self) { font in
                            Text(font.rawValue).font(.custom(font.rawValue, size: 13)).tag(font)
                        }
                    }
                    .help("Font")
                    RibbonPicker("Font Size", selection: $format.fontSize, value: "\(format.fontSize.formatted()) pt") {
                        ForEach(Array(stride(from: ResumeFormat.fontSizes.lowerBound, through: ResumeFormat.fontSizes.upperBound, by: 0.5)), id: \.self) {
                            Text("\($0.formatted()) pt").tag($0)
                        }
                    }
                    .help("Font size")
                    CivaMenuPicker("Color", selection: $format.accent, value: Text(format.accent.title)) {
                        ForEach(ResumeFormat.Accent.allCases, id: \.self) { accent in
                            Label {
                                Text(accent.title)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(accent.color)
                            }
                            .tag(accent)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(format.accent.color).frame(width: 9, height: 9).overlay { Circle().strokeBorder(Color.fieldBorder) }
                            Text(format.accent.title)
                        }
                    }
                    .help("Color of your name and section headings")
                }
                RibbonGroup("Spacing") {
                    RibbonItem("Lines", guide: .lineSpacing, help: "Space between lines, as a multiple of the font's height", onHover: onHoverGuide) {
                        RibbonPicker("Line Spacing", selection: $format.lineSpacing, value: lineSpacingName(format.lineSpacing)) {
                            ForEach(ResumeFormat.lineSpacings, id: \.self) { value in
                                Text(lineSpacingName(value)).tag(value)
                            }
                        }
                    }
                    RibbonItem("Sections", guide: .sectionSpacing, help: "Space above each section heading", onHover: onHoverGuide) {
                        ValueStepper(value: $format.sectionSpacing, range: ResumeFormat.sectionSpacings, step: 2)
                    }
                    RibbonItem("Entries", guide: .entrySpacing, help: "Space between entries in a section", onHover: onHoverGuide) {
                        ValueStepper(
                            value: Binding(get: { format.entryGap }, set: { format.entrySpacing = $0 }),
                            range: ResumeFormat.entrySpacings, step: 1
                        )
                    }
                    RibbonItem("Margins", guide: .margins, help: "Page margins: top and bottom, then the sides", onHover: onHoverGuide) {
                        Menu {
                            Picker("Top and Bottom", selection: $format.margins) {
                                ForEach(ResumeFormat.Margins.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.inline)
                            Picker("Left and Right", selection: Binding(get: { format.sideMargin }, set: { format.sideMargins = $0 })) {
                                ForEach(ResumeFormat.Margins.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            MenuFieldLabel { Text(marginsTitle) }
                        }
                        .menuStyle(.button)
                        .menuIndicator(.hidden)
                        .civaButton(.secondary)
                        .fixedSize()
                    }
                }
                RibbonGroup("Lines") {
                    Toggle("Dividers", isOn: Binding(get: { format.dividers }, set: { format.showsDividers = $0 }))
                        .toggleStyle(.checkbox)
                        .help("A line under each section heading")
                    // "0.5 pt" with a point, like the other spacing values, whatever the Mac's language.
                    RibbonPicker("Thickness", selection: Binding(get: { format.dividerWidth }, set: { format.dividerWeight = $0 }), value: String(format: "%g pt", format.dividerWidth)) {
                        ForEach(ResumeFormat.dividerWeights, id: \.self) { Text(String(format: "%g pt", $0)).tag($0) }
                    }
                    .disabled(!format.dividers)
                    .help("Divider thickness")
                }
                RibbonGroup("Proof") {
                    Toggle("Proof Check", isOn: Binding(get: { format.linksProof != false }, set: { format.linksProof = $0 }))
                        .toggleStyle(.checkbox)
                        .help("A small gray check after titles with a proof link; clicking the title opens it from the PDF")
                        .popoverTip(currentTip(CivaTip.proof), arrowEdge: .top)
                }
                RibbonGroup("Page", showsDivider: false) {
                    PaperChoice(selection: $format.paper)
                        .help("Paper size")
                    RibbonPicker("Dates", selection: Binding(get: { format.dateStyle ?? .short }, set: { format.dateStyle = $0 }), value: (format.dateStyle ?? .short).title) {
                        ForEach(ResumeFormat.DateStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .help("How dates print")
                    Text(pageSummary)
                        .monospacedDigit()
                        // Neutral: Ovi's page-count tip carries the advice (DESIGN.md §12).
                        .foregroundStyle(Color.textSecondary)
                        .help(Text(pageSummary))
                }
            }
            Button("Guides", systemImage: "ruler") { showsGuides.toggle() }
                .civaButton(showsGuides ? .primary : .secondary)
                .accessibilityAddTraits(showsGuides ? .isSelected : [])
                .help(showsGuides ? "Hide the distance guides" : "Keep the distance guides on the preview")
            .padding(.top, 6)
            .padding(.trailing, 10)
        }
        .controlSize(.small)
        .padding(.vertical, 6)
        .background(Color.canvas)
    }

    private var marginsTitle: String {
        format.sideMargin == format.margins ? format.margins.inches : "\(format.margins.inches) · \(format.sideMargin.inches)"
    }

    private func lineSpacingName(_ value: Double) -> String {
        var copy = format
        copy.lineSpacing = value
        return copy.lineSpacingName
    }

    private var pageSummary: String {
        String(AttributedString(localized: "^[\(pageCount) page](inflect: true)").characters)
    }
}

/// Controls with a small caption underneath and a line after, like a Word ribbon group.
private struct RibbonGroup<Content: View>: View {
    let title: LocalizedStringKey
    var showsDivider = true
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
                HStack(alignment: .bottom, spacing: 8) { content }
                    .fixedSize()
                    // Same height for every group, so the captions line up.
                    .frame(height: 34, alignment: .bottom)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 10)
            if showsDivider {
                Rectangle().fill(Color.hairline).frame(width: 1).padding(.vertical, Space.s)
            }
        }
        .fixedSize()
    }
}

/// A spacing control with its own small label above it. Hovering shows its guide on the preview.
private struct RibbonItem<Content: View>: View {
    let title: LocalizedStringKey
    let guide: ResumeRenderer.Guide
    let help: LocalizedStringKey
    let onHover: (ResumeRenderer.Guide, Bool) -> Void
    @ViewBuilder let content: Content

    init(
        _ title: LocalizedStringKey, guide: ResumeRenderer.Guide, help: LocalizedStringKey,
        onHover: @escaping (ResumeRenderer.Guide, Bool) -> Void, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.guide = guide
        self.help = help
        self.onHover = onHover
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            content
        }
        .contentShape(Rectangle())
        .help(help)
        .onHover { onHover(guide, $0) }
    }
}

/// A ribbon menu in a paper field (DESIGN.md §8.5): white fill, hairline border, ink text.
private struct RibbonPicker<Value: Hashable, Items: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let value: String
    @ViewBuilder let items: Items

    init(_ title: LocalizedStringKey, selection: Binding<Value>, value: String, @ViewBuilder items: () -> Items) {
        self.title = title
        _selection = selection
        self.value = value
        self.items = items()
    }

    var body: some View {
        CivaMenuPicker(title, selection: $selection, value: Text(value)) { items } label: { Text(value) }
    }
}

/// A menu's label with the same chevron as `CivaMenuPicker`, for menus that aren't one picker.
private struct MenuFieldLabel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
    }
}

/// A4 or US Letter: paper fields side by side, the chosen one cobalt.
private struct PaperChoice: View {
    @Binding var selection: ResumeFormat.Paper

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ResumeFormat.Paper.allCases, id: \.self) { paper in
                Button(paper.title) { selection = paper }
                    .civaButton(selection == paper ? .primary : .secondary)
                    .accessibilityAddTraits(selection == paper ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paper")
    }
}

/// "10 pt" with − and + beside it, in a paper field.
private struct ValueStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 2) {
            Text("\(value.formatted()) pt")
                .font(.body.weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
            Stepper("Value", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.leading, Space.s)
        .padding(.trailing, 2)
        .frame(height: Size.controlSmall)
        .background(Color.surface, in: .rect(cornerRadius: Radius.control))
        .overlay { RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Color.fieldBorder) }
    }
}

/// Lays children left to right and starts a new row when one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: row.height))
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}

extension ResumeFormat.Margins {
    var title: String {
        switch self {
        case .narrow: String(localized: "Narrow (0.5 in)")
        case .normal: String(localized: "Normal (0.75 in)")
        case .wide: String(localized: "Wide (1 in)")
        }
    }
}

extension ResumeFormat.DateStyle {
    var title: String {
        let sample = YearMonth(year: 2024, month: 3)
        return sample.formatted(self)
    }
}

extension ResumeFormat.Template {
    var title: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .mit: String(localized: "MIT")
        case .harvard: String(localized: "Harvard")
        case .tech: String(localized: "Tech")
        }
    }
}

extension ResumeFormat.Paper {
    var title: String {
        switch self {
        case .a4: String(localized: "A4")
        case .letter: String(localized: "US Letter")
        }
    }
}

extension ResumeFormat.Accent {
    var title: String {
        switch self {
        case .black: String(localized: "Black")
        case .navy: String(localized: "Navy")
        case .teal: String(localized: "Teal")
        case .burgundy: String(localized: "Burgundy")
        }
    }

    /// Matches the renderer's colors.
    var color: Color {
        switch self {
        case .black: .black
        case .navy: Color(red: 0.11, green: 0.20, blue: 0.40)
        case .teal: Color(red: 0.04, green: 0.38, blue: 0.40)
        case .burgundy: Color(red: 0.45, green: 0.10, blue: 0.18)
        }
    }
}

#Preview {
    @Previewable @State var format = ResumeFormat()
    @Previewable @State var showsGuides = false
    ResumeFormatBar(format: $format, pageCount: 1, showsGuides: $showsGuides)
        .frame(width: 1000)
}
