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
                [education.degree.isBlank ? education.degreeLevel?.title ?? "" : education.degree,
                 YearMonth.rangeText(start: education.start, end: education.end)]
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
                OrganizationField(title: "Institution", name: editor.binding(\.institution), prompt: Text("Required"))
                FieldError(editor.error(for: \.institution))
                OptionPicker("Degree Level", selection: editor.binding(\.degreeLevelRaw), options: DegreeLevel.allCases)
                TextField("Degree", text: editor.binding(\.degree), prompt: Text("Bachelor of Computer Science"))
                TextField("Field of Study", text: editor.binding(\.fieldOfStudy), prompt: Text("Informatics"))
                TextField("Location", text: editor.binding(\.location), prompt: Text("City, Country"))
            }
            GradeSection(editor: editor)
            Section("Dates") {
                YearMonthField(title: String(localized: "Start"), value: editor.binding(\.start))
                YearMonthField(title: String(localized: "End"), value: editor.binding(\.end))
                FieldError(editor.error(for: \.end))
            }
            Section("Academic Work") {
                TextField("Thesis", text: editor.binding(\.thesis), prompt: Text("Title of your thesis or final project"), axis: .vertical)
                TextField("Honors", text: editor.binding(\.honors), prompt: Text("Cum Laude, Dean's List"))
            }
            Section("Relevant Coursework") {
                StringListEditor(
                    items: editor.binding(\.coursework),
                    prompt: String(localized: "Course name"),
                    addTitle: String(localized: "Add Course")
                )
            }
            Section("Description") {
                TextField(
                    "Description",
                    text: editor.binding(\.details),
                    prompt: Text("Activities, exchange programs, other details"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(3...10)
            }
            Section {
                ProofField(editor: editor, title: "Proof Link", link: \.proofURL)
            } header: {
                Text("Proof")
            } footer: {
                Text("A diploma or transcript. With a link or an attached document, this record shows a Verified seal.")
            }
            DocumentsSection(editor: editor)
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }
}

/// The grade as a number out of a chosen maximum: GPA 3.86 / 4.00, Score 91.4 / 100, or any other scale.
private struct GradeSection: View {
    let editor: RecordEditor<Education>
    /// Shows the custom maximum field even while it holds a common value.
    @State private var isCustomScale = false

    var body: some View {
        let education = editor.record
        Section {
            Picker("Grade Name", selection: editor.binding(\.gradeLabelRaw)) {
                ForEach(GradeLabel.allCases) { Text($0.title).tag($0.rawValue) }
            }
            TextField("Grade", value: editor.binding(\.gradeValue), format: .number, prompt: Text("3.86"))
            FieldError(editor.error(for: \.gradeValue))
            Picker("Out Of", selection: scaleChoice) {
                ForEach(Grade.commonScales, id: \.self) { Text(Grade(value: 0, scale: $0).scaleText()).tag(Double?.some($0)) }
                Divider()
                Text("Other…").tag(Double?.none)
            }
            if showsCustomScale {
                TextField("Maximum", value: editor.binding(\.gradeScale), format: .number, prompt: Text("20"))
                FieldError(editor.error(for: \.gradeScale))
            }
            if !education.grade.isBlank {
                LabeledContent("Typed Grade") {
                    HStack {
                        Text(education.grade)
                        RemoveButton { editor.update { $0.grade = "" } }
                    }
                }
            }
        } header: {
            Text("Grade")
        } footer: {
            if !education.grade.isBlank {
                Text("Civa couldn't read the typed grade as a number. Enter it above, then remove the typed one.")
            }
        }
        .onAppear { isCustomScale = !Grade.commonScales.contains(education.gradeScale) }
    }

    private var showsCustomScale: Bool {
        isCustomScale || !Grade.commonScales.contains(editor.record.gradeScale)
    }

    /// A common maximum, or nil for Other.
    private var scaleChoice: Binding<Double?> {
        Binding(
            get: { showsCustomScale ? nil : editor.record.gradeScale },
            set: { scale in
                isCustomScale = scale == nil
                if let scale { editor.update { $0.gradeScale = scale } }
            }
        )
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
