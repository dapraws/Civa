//
//  EducationView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

struct EducationList: View {
    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Education"),
            empty: .init(
                title: String(localized: "No Education Yet"),
                message: String(localized: "Add schools, degrees, and courses."),
                systemImage: "graduationcap"
            ),
            order: { recency($0) > recency($1) },
            subtitle: { education in
                [education.degree, YearMonth.rangeText(start: education.start, end: education.end)]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            },
            makeRecord: { Education(institution: "") },
            editor: { EducationForm(editor: $0) }
        )
    }

    private func recency(_ education: Education) -> YearMonth {
        YearMonth.recency(start: education.start, end: education.end)
    }
}

struct EducationForm: View {
    let editor: RecordEditor<Education>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Institution", text: editor.binding(\.institution), prompt: Text("Required"))
                FieldError(editor.error(for: \.institution))
                TextField("Degree", text: editor.binding(\.degree), prompt: Text("Bachelor of Science"))
                TextField("Field of Study", text: editor.binding(\.fieldOfStudy), prompt: Text("Computer Science"))
                TextField("Location", text: editor.binding(\.location), prompt: Text("City, Country"))
                TextField("Grade", text: editor.binding(\.grade), prompt: Text("3.7 / 4.0"))
            }
            Section("Dates") {
                YearMonthField(title: String(localized: "Start"), value: editor.binding(\.start))
                YearMonthField(title: String(localized: "End"), value: editor.binding(\.end))
                FieldError(editor.error(for: \.end))
            }
            Section("Description") {
                TextField(
                    "Description",
                    text: editor.binding(\.details),
                    prompt: Text("Thesis, activities, relevant courses"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(3...10)
            }
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }
}

#Preview("List") {
    NavigationStack {
        EducationList()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    EducationForm(editor: .preview())
        .frame(width: 600, height: 700)
        .previewEnvironment()
}
