//
//  ResumeFormatBar.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Word-style format dropdowns above the preview. Options are limited so the resume stays
/// single-column and ATS-friendly (FR-036).
struct ResumeFormatBar: View {
    @Binding var format: ResumeFormat
    let pageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Scrolls sideways when the preview is narrow; the page count stays put.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Picker("Template", selection: Binding(get: { format.layout }, set: { format.apply($0) })) {
                        ForEach(ResumeFormat.Template.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .help("Template: sets the layout, and a font you can still change")

                    Picker("Font", selection: $format.font) {
                        ForEach(ResumeFormat.Font.allCases, id: \.self) { font in
                            Text(font.rawValue).font(.custom(font.rawValue, size: 13)).tag(font)
                        }
                    }
                    .frame(width: 130)
                    .help("Font")

                    Picker("Font Size", selection: $format.fontSize) {
                        ForEach(Array(stride(from: ResumeFormat.fontSizes.lowerBound, through: ResumeFormat.fontSizes.upperBound, by: 0.5)), id: \.self) {
                            Text("\($0.formatted()) pt").tag($0)
                        }
                    }
                    .help("Font size")

                    Menu {
                        Picker("Line Spacing", selection: $format.lineSpacing) {
                            ForEach(ResumeFormat.lineSpacings, id: \.self) { Text($0.formatted()).tag($0) }
                        }
                        Picker("Space Between Sections", selection: $format.sectionSpacing) {
                            ForEach(Array(stride(from: ResumeFormat.sectionSpacings.lowerBound, through: ResumeFormat.sectionSpacings.upperBound, by: 2)), id: \.self) {
                                Text("\($0.formatted()) pt").tag($0)
                            }
                        }
                        Picker("Margins", selection: $format.margins) {
                            ForEach(ResumeFormat.Margins.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Picker("Paper", selection: $format.paper) {
                            ForEach(ResumeFormat.Paper.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Picker("Dates", selection: Binding(
                            get: { format.dateStyle ?? .short },
                            set: { format.dateStyle = $0 }
                        )) {
                            ForEach(ResumeFormat.DateStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Divider()
                        Toggle("Show Employment Type", isOn: option(\.showsEmploymentType, default: false))
                        Toggle("Show Work Arrangement", isOn: option(\.showsWorkArrangement, default: false))
                        Toggle("Show GPA or Score", isOn: option(\.showsGrade, default: true))
                        Toggle("Link Proof", isOn: option(\.linksProof, default: true))
                            .help("A small check after titles with proof; clicking the title opens it from the PDF")
                        Divider()
                        Toggle("Divider Lines", isOn: Binding(get: { format.dividers }, set: { format.showsDividers = $0 }))
                            .help("A line under each section heading")
                        Toggle("Summary Heading", isOn: option(\.showsSummaryHeading, default: false))
                            .help("Give the summary its own heading, or keep it right under your contact details")
                    } label: {
                        Label("Layout", systemImage: "rectangle.split.1x2")
                    }
                    .help("Spacing, margins, dates, and what each entry shows")

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
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            .scrollBounceBehavior(.basedOnSize)

            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    /// An option stored as an optional, where nil means its default.
    private func option(_ field: WritableKeyPath<ResumeFormat, Bool?>, default value: Bool) -> Binding<Bool> {
        Binding(get: { format[keyPath: field] ?? value }, set: { format[keyPath: field] = $0 })
    }

    private var summary: String {
        String(AttributedString(localized: "^[\(pageCount) page](inflect: true)").characters)
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
    ResumeFormatBar(format: $format, pageCount: 1)
        .frame(width: 560)
}
