//
//  StartsWithoutFocus.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import SwiftUI

extension View {
    /// Opens with no field focused. macOS focuses the first text field and selects its text,
    /// which looks like a highlight by mistake and lets one keystroke replace a saved name.
    /// Off for new records, where typing straight into the first field is what you want.
    func startsWithoutFocus(_ isOn: Bool = true) -> some View {
        onAppear {
            guard isOn else { return }
            // After the window has made its own choice of first responder.
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
    }
}

#Preview {
    Form {
        TextField("Full Name", text: .constant("Raka Pratama"))
    }
    .formStyle(.grouped)
    .startsWithoutFocus()
}
