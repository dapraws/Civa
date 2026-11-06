//
//  CustomFieldsSection.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Extra name/value details kept with a record (FR-012).
struct CustomFieldsSection: View {
    @Binding var fields: [CustomField]

    var body: some View {
        Section {
            PairListEditor(
                items: $fields,
                first: \.name,
                second: \.value,
                prompts: (String(localized: "Name"), String(localized: "Value")),
                addTitle: String(localized: "Add Field"),
                makeItem: { CustomField(name: "", value: "") }
            )
        } header: {
            Text("Custom Fields")
        } footer: {
            Text("Custom fields stay in your profile. They aren't added to resumes automatically.")
        }
    }
}

#Preview {
    @Previewable @State var fields = [CustomField(name: "Team Size", value: "6")]
    Form {
        CustomFieldsSection(fields: $fields)
    }
    .formStyle(.grouped)
}
