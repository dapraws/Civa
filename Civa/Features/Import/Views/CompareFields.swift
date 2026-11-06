//
//  CompareFields.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// The profile's value and the incoming value side by side for each field that differs; click
/// one to keep it (FR-024). Lines such as impacts are kept from both.
struct CompareFields: View {
    let existing: ImportItem
    let incoming: ImportItem
    /// Fields that take the incoming value.
    @Binding var picks: Set<ImportField>
    let incomingTitle: String

    var body: some View {
        let differences = ImportMatcher.differences(incoming, existing)
        let newLines = ImportItem.union(existing.bullets, incoming.bullets).count - existing.bullets.count
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("Field").gridColumnAlignment(.leading)
                Text("In Your Profile")
                Text(incomingTitle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(differences, id: \.self) { field in
                GridRow {
                    Text(field.label(for: existing.category))
                        .foregroundStyle(.secondary)
                    choice(existing.display(field), isPicked: !picks.contains(field)) { picks.remove(field) }
                    choice(incoming.display(field), isPicked: picks.contains(field)) { picks.insert(field) }
                }
            }
            if newLines > 0 {
                GridRow {
                    Text("Details")
                        .foregroundStyle(.secondary)
                    Text("Keeps all \(existing.bullets.count) of yours and adds \(newLines) new")
                        .gridCellColumns(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func choice(_ value: String, isPicked: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Label {
                Text(value.isBlank ? String(localized: "Empty") : value)
                    .foregroundStyle(value.isBlank ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var picks: Set<ImportField> = [.location]
    Form {
        CompareFields(
            existing: ImportItem(category: .experience, title: "iOS Engineer", subtitle: "Tokopedia", start: YearMonth(year: 2024, month: 3), bullets: ["Cut drop-off"]),
            incoming: ImportItem(category: .experience, title: "iOS Engineer", subtitle: "PT Tokopedia", location: "Jakarta", start: YearMonth(year: 2024, month: 2), bullets: ["Shipped sync"]),
            picks: $picks,
            incomingTitle: "From cv.pdf"
        )
    }
    .formStyle(.grouped)
    .frame(width: 560)
}
