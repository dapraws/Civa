//
//  ClaudePermissionsSection.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Read and Suggest per category (FR-071). Suggesting needs reading, so the switches move together.
struct ClaudePermissionsSection: View {
    @Bindable private var permissions = ClaudePermissions.shared

    var body: some View {
        Section {
            ForEach(ClaudeCategory.allCases) { category in
                HStack {
                    Text(category.title)
                    Spacer()
                    Toggle("Read", isOn: read(category))
                    Toggle("Suggest", isOn: suggest(category))
                }
                // The system checkbox ignores .tint and draws in Civa's blue accent.
                .toggleStyle(ClaudeCheckboxStyle())
            }
        } header: {
            SectionTitle("What Claude May Use")
        } footer: {
            Text("Read lets Claude see confirmed records in that category. Suggest lets it propose changes, which wait for your approval. Records that still need review are never shared.")
        }
    }

    private func read(_ category: ClaudeCategory) -> Binding<Bool> {
        Binding(
            get: { permissions.read.contains(category) },
            set: { isOn in
                if isOn { permissions.read.insert(category) } else {
                    permissions.read.remove(category)
                    permissions.suggest.remove(category)
                }
            }
        )
    }

    private func suggest(_ category: ClaudeCategory) -> Binding<Bool> {
        Binding(
            get: { permissions.suggest.contains(category) },
            set: { isOn in
                if isOn {
                    permissions.suggest.insert(category)
                    permissions.read.insert(category)
                } else {
                    permissions.suggest.remove(category)
                }
            }
        )
    }
}

/// The latest entries of the audit log (FR-074). The AI Activity Center shows all of it.
struct ClaudeRecentActivitySection: View {
    @Query(sort: \ClaudeActivity.date, order: .reverse) private var activity: [ClaudeActivity]

    var body: some View {
        if !activity.isEmpty {
            Section(civa: "Recent Claude Activity") {
                ForEach(activity.prefix(5)) { ClaudeActivityRow(entry: $0) }
            }
        }
    }
}

#Preview {
    Form {
        ClaudePermissionsSection()
        ClaudeRecentActivitySection()
    }
    .civaForm()
    .frame(width: 560, height: 600)
    .previewEnvironment()
}

/// A checkbox filled with Claude's clay (claudeText, so the check keeps 4.5:1 on canvas in both modes), for switches that decide what Claude may do.
struct ClaudeCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: Space.xs) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(configuration.isOn ? Color.claudeText : Color.surface)
                    .strokeBorder(configuration.isOn ? Color.clear : Color.fieldBorder)
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.canvas)
                        }
                    }
                    .frame(width: 14, height: 14)
                configuration.label
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
    }
}

