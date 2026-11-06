//
//  CertificationView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

struct CertificationList: View {
    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Certification"),
            empty: .init(
                title: String(localized: "No Certifications Yet"),
                message: String(localized: "Add licenses and certificates."),
                systemImage: "checkmark.seal"
            ),
            order: { ($0.issued ?? .distantFuture) > ($1.issued ?? .distantFuture) },
            subtitle: { certification in
                [certification.issuer, certification.issued?.formatted() ?? ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            },
            makeRecord: { Certification(name: "") },
            editor: { CertificationForm(editor: $0) }
        )
    }
}

struct CertificationForm: View {
    let editor: RecordEditor<Certification>

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Name", text: editor.binding(\.name), prompt: Text("Required"))
                FieldError(editor.error(for: \.name))
                TextField("Issuer", text: editor.binding(\.issuer), prompt: Text("Issuing organization"))
            }
            Section("Dates") {
                YearMonthField(title: String(localized: "Issued"), value: editor.binding(\.issued))
                YearMonthField(title: String(localized: "Expires"), value: editor.binding(\.expires))
                FieldError(editor.error(for: \.expires))
            }
            Section("Credential") {
                TextField("Credential ID", text: editor.binding(\.credentialID))
                TextField("Credential URL", text: editor.binding(\.credentialURL), prompt: Text("https://"))
            }
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }
}

#Preview("List") {
    NavigationStack {
        CertificationList()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    CertificationForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
