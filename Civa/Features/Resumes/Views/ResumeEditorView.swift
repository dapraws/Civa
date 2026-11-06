//
//  ResumeEditorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Form on the left with section tabs, live preview on the right (FR-032, FR-033).
/// The preview is the rendered PDF itself and can't be edited.
struct ResumeEditorView: View {
    enum Tab: CaseIterable, Identifiable {
        case details, header, summary, sections, format

        var id: Self { self }

        var title: String {
            switch self {
            case .details: String(localized: "Details")
            case .header: String(localized: "Header")
            case .summary: String(localized: "Summary")
            case .sections: String(localized: "Sections")
            case .format: String(localized: "Format")
            }
        }
    }

    let editor: RecordEditor<Resume>
    @State private var tab: Tab = .sections

    var body: some View {
        // A plain stack: a split view nested in the list/detail split overflows under the list.
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(10)

                Form {
                    switch tab {
                    case .details: details
                    case .header: header
                    case .summary: summary
                    case .sections: ResumeSectionsForm(document: editor.binding(\.document))
                    case .format: ResumeFormatForm(format: editor.binding(\.document).format)
                    }
                }
                .formStyle(.grouped)
            }
            .frame(minWidth: 340, maxWidth: .infinity)

            Divider()

            PDFPreview(data: ResumeRenderer.pdf(for: editor.record.document))
                .frame(minWidth: 240, maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ResumeExportButton(resume: editor.record)
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        Section {
            TextField("Resume Name", text: editor.binding(\.title), prompt: Text("Required"))
            FieldError(editor.error(for: \.title))
            TextField("Target Position", text: editor.binding(\.targetPosition), prompt: Text("iOS Developer"))
        } footer: {
            Text("Only you see these. They don't appear on the resume.")
        }
        Section("Job Description") {
            TextField(
                "Job Description",
                text: editor.binding(\.jobDescription),
                prompt: Text("Paste the job description for this version"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(6...24)
        }
    }

    @ViewBuilder
    private var header: some View {
        let header = editor.binding(\.document).header
        Section {
            TextField("Full Name", text: header.fullName)
            TextField("Headline", text: header.headline, prompt: Text("iOS Engineer"))
            TextField("Email", text: header.email, prompt: Text("name@example.com"))
            TextField("Phone", text: header.phone)
            TextField("Location", text: header.location, prompt: Text("City, Country"))
        }
        Section("Links") {
            PairListEditor(
                items: header.links,
                first: \.label,
                second: \.url,
                prompts: (String(localized: "Label"), String(localized: "URL")),
                addTitle: String(localized: "Add Link"),
                makeItem: { ProfileLink(label: "", url: "") }
            )
        }
    }

    private var summary: some View {
        Section {
            TextField(
                "Summary",
                text: editor.binding(\.document).summary,
                prompt: Text("Two or three sentences about your experience and focus"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(4...12)
        } footer: {
            Text("Shown under your name, without a heading. Leave it empty if you don't need one. Keep it to what your experience supports.")
        }
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1000, height: 700)
        .previewEnvironment()
}
