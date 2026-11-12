//
//  FieldStyle.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Civa's text field (DESIGN.md §7.2): white field, warm border, cobalt border and a soft glow
/// while focused, red border on error. The error message itself stays `FieldError`.
struct CivaFieldStyle: TextFieldStyle {
    var hasError = false

    init(hasError: Bool = false) {
        self.hasError = hasError
    }

    func _body(configuration: TextField<Self._Label>) -> some View {
        CivaField(hasError: hasError) { configuration }
    }
}

extension TextFieldStyle where Self == CivaFieldStyle {
    static var civa: CivaFieldStyle { CivaFieldStyle() }
}

private struct CivaField<Field: View>: View {
    let hasError: Bool
    @ViewBuilder let field: Field
    @FocusState private var isFocused: Bool

    var body: some View {
        field
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, Space.s)
            .frame(minHeight: Size.control)
            .background(Color.surface, in: .rect(cornerRadius: Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(hasError ? Color.danger : isFocused ? Color.accent : Color.fieldBorder)
            }
            .overlay {
                if isFocused && !hasError {
                    RoundedRectangle(cornerRadius: Radius.control + 1.5)
                        .stroke(Color.accent.opacity(0.25), lineWidth: 3)
                        .padding(-1.5)
                        .allowsHitTesting(false)
                }
            }
            .animation(Motion.fast, value: isFocused)
    }
}

/// The trigger of a dropdown (DESIGN.md §7.3): looks like a Secondary button with a trailing
/// chevron; the menu itself is the system menu. SwiftUI has no public custom `PickerStyle`.
struct CivaMenuPicker<Value: Hashable, Items: View, Label: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    @ViewBuilder let items: Items
    @ViewBuilder let label: Label

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        @ViewBuilder items: () -> Items,
        @ViewBuilder label: () -> Label
    ) {
        self.title = title
        _selection = selection
        self.items = items()
        self.label = label()
    }

    var body: some View {
        Menu {
            Picker(title, selection: $selection) { items }
                .pickerStyle(.inline)
                .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                label
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.secondary)
        .fixedSize()
        .accessibilityLabel(Text(title))
    }
}

private struct FieldGallery: View {
    @State private var name = "Gojek"
    @State private var empty = ""
    @State private var status = ApplicationStatus.applied

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Company", text: $name).textFieldStyle(.civa)
            TextField("Company", text: $empty, prompt: Text("Tokopedia")).textFieldStyle(.civa)
            TextField("Position", text: $empty).textFieldStyle(CivaFieldStyle(hasError: true))
            FieldError("Enter a position.")
            CivaMenuPicker("Status", selection: $status) {
                ForEach(ApplicationStatus.allCases) { Text($0.title).tag($0) }
            } label: {
                StatusMark(status)
            }
        }
        .frame(width: 320)
        .padding()
        .background(Color.canvas)
    }
}

#Preview { FieldGallery() }

#Preview("Dark") { FieldGallery().preferredColorScheme(.dark) }
