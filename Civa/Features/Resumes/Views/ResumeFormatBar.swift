//
//  ResumeFormatBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// A Word-style ribbon above the preview: grouped controls, each group captioned, all visible.
/// When the preview is narrow the groups wrap onto more rows instead of folding into a menu.
/// Options are limited so the resume stays single-column and ATS-friendly (FR-036).
struct ResumeFormatBar: View {
    @Binding var format: ResumeFormat
    let pageCount: Int
    /// Keeps every distance guide on.
    @Binding var showsGuides: Bool
    /// The pointer entered (true) or left (false) a spacing control.
    var onHoverGuide: (ResumeRenderer.Guide, Bool) -> Void = { _, _ in }

    var body: some View {
        FlowLayout(spacing: 0, rowSpacing: 6) {
            RibbonGroup("Template") {
                Picker("Template", selection: Binding(get: { format.layout }, set: { format.apply($0) })) {
                    ForEach(ResumeFormat.Template.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .help("Template: sets the layout, and a font you can still change")
            }
            RibbonGroup("Font") {
                Picker("Font", selection: $format.font) {
                    ForEach(ResumeFormat.Font.allCases, id: \.self) { font in
                        Text(font.rawValue).font(.custom(font.rawValue, size: 13)).tag(font)
                    }
                }
                .help("Font")
                Picker("Font Size", selection: $format.fontSize) {
                    ForEach(Array(stride(from: ResumeFormat.fontSizes.lowerBound, through: ResumeFormat.fontSizes.upperBound, by: 0.5)), id: \.self) {
                        Text("\($0.formatted()) pt").tag($0)
                    }
                }
                .help("Font size")
                Picker("Accent Color", selection: $format.accent) {
                    ForEach(ResumeFormat.Accent.allCases, id: \.self) { accent in
                        Label {
                            Text(accent.title)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(accent.color)
                        }
                        .tag(accent)
                    }
                }
                .help("Accent color for your name and section headings")
            }
            RibbonGroup("Spacing") {
                Picker("Line Spacing", selection: $format.lineSpacing) {
                    ForEach(ResumeFormat.lineSpacings, id: \.self) { Text(spacingTitle($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Line spacing")
                .onHover { onHoverGuide(.lineSpacing, $0) }
                HStack(spacing: 2) {
                    Text("\(Int(format.sectionSpacing)) pt").monospacedDigit()
                    Stepper("Space Above Headings", value: $format.sectionSpacing, in: ResumeFormat.sectionSpacings, step: 2)
                }
                .help("Space above each section heading")
                .onHover { onHoverGuide(.sectionSpacing, $0) }
                Picker("Margins", selection: $format.margins) {
                    ForEach(ResumeFormat.Margins.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .help("Page margins")
                .onHover { onHoverGuide(.margins, $0) }
                Toggle(isOn: $showsGuides) {
                    Image(systemName: "ruler")
                }
                .toggleStyle(.button)
                .help(showsGuides ? "Hide distance guides" : "Keep distance guides on the preview")
            }
            RibbonGroup("Page") {
                Picker("Paper", selection: $format.paper) {
                    ForEach(ResumeFormat.Paper.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Paper size")
                Picker("Dates", selection: Binding(get: { format.dateStyle ?? .short }, set: { format.dateStyle = $0 })) {
                    ForEach(ResumeFormat.DateStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .help("How dates print")
                Text(summary)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            RibbonGroup("Show", showsDivider: false, hidesLabels: false) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                    // Two columns, so the group fits a narrow preview.
                    GridRow {
                        Toggle("Employment Type", isOn: option(\.showsEmploymentType, default: false))
                        Toggle("Divider Lines", isOn: Binding(get: { format.dividers }, set: { format.showsDividers = $0 }))
                            .help("A line under each section heading")
                    }
                    GridRow {
                        Toggle("Work Arrangement", isOn: option(\.showsWorkArrangement, default: false))
                        Toggle("Summary Heading", isOn: option(\.showsSummaryHeading, default: false))
                            .help("Give the summary its own heading, or keep it right under your contact details")
                    }
                    GridRow {
                        Toggle("GPA or Score", isOn: option(\.showsGrade, default: true))
                        Toggle("Proof Check", isOn: option(\.linksProof, default: true))
                            .help("A small check after titles with proof; clicking the title opens it from the PDF")
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    /// An option stored as an optional, where nil means its default.
    private func option(_ field: WritableKeyPath<ResumeFormat, Bool?>, default value: Bool) -> Binding<Bool> {
        Binding(get: { format[keyPath: field] ?? value }, set: { format[keyPath: field] = $0 })
    }

    private func spacingTitle(_ value: Double) -> String {
        var copy = format
        copy.lineSpacing = value
        return copy.lineSpacingTitle
    }

    private var summary: String {
        String(AttributedString(localized: "^[\(pageCount) page](inflect: true)").characters)
    }
}

/// Controls with a small caption underneath and a separator after, like a Word ribbon group.
private struct RibbonGroup<Content: View>: View {
    let title: LocalizedStringKey
    var showsDivider = true
    /// Pickers show their choice, not their name; checkboxes need theirs.
    var hidesLabels = true
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, showsDivider: Bool = true, hidesLabels: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsDivider = showsDivider
        self.hidesLabels = hidesLabels
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
                HStack(spacing: 6) { content }
                    .labelsVisibility(hidesLabels ? .hidden : .automatic)
                    .fixedSize()
                    .frame(maxHeight: .infinity)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            if showsDivider { Divider().padding(.vertical, 2) }
        }
        .fixedSize()
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
        .frame(width: 560)
}
