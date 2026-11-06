//
//  ResumeFormatForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Layout options, limited so the resume stays single-column and ATS-friendly (FR-036).
struct ResumeFormatForm: View {
    @Binding var format: ResumeFormat

    var body: some View {
        Section {
            Picker("Font", selection: $format.font) {
                ForEach(ResumeFormat.Font.allCases, id: \.self) { font in
                    Text(font.rawValue).font(.custom(font.rawValue, size: 13)).tag(font)
                }
            }
            Stepper(value: $format.fontSize, in: ResumeFormat.fontSizes, step: 0.5) {
                LabeledContent("Font Size", value: "\(format.fontSize.formatted()) pt")
            }
            Picker("Line Spacing", selection: $format.lineSpacing) {
                ForEach(ResumeFormat.lineSpacings, id: \.self) { spacing in
                    Text(spacing.formatted()).tag(spacing)
                }
            }
            Stepper(value: $format.sectionSpacing, in: ResumeFormat.sectionSpacings, step: 2) {
                LabeledContent("Space Between Sections", value: "\(format.sectionSpacing.formatted()) pt")
            }
        }
        Section {
            Picker("Margins", selection: $format.margins) {
                ForEach(ResumeFormat.Margins.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Paper", selection: $format.paper) {
                ForEach(ResumeFormat.Paper.allCases, id: \.self) { Text($0.title).tag($0) }
            }
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
        } footer: {
            Text("The accent color applies to your name and section headings only. Options are limited so the resume stays single-column and ATS-friendly.")
        }
    }
}

private extension ResumeFormat.Margins {
    var title: String {
        switch self {
        case .narrow: String(localized: "Narrow (0.5 in)")
        case .normal: String(localized: "Normal (0.75 in)")
        case .wide: String(localized: "Wide (1 in)")
        }
    }
}

private extension ResumeFormat.Paper {
    var title: String {
        switch self {
        case .a4: String(localized: "A4")
        case .letter: String(localized: "US Letter")
        }
    }
}

private extension ResumeFormat.Accent {
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
    Form {
        ResumeFormatForm(format: $format)
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 520)
}
