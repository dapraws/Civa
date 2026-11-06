//
//  FieldError.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Inline validation message under a form field. Renders nothing when there's no error.
struct FieldError: View {
    let message: String?

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    Form {
        TextField("Role", text: .constant(""))
        FieldError("Enter a role.")
    }
    .formStyle(.grouped)
}
