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
                .toggleStyle(.checkbox)
            }
        } header: {
            Text("What Claude May Use")
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
            Section("Recent Claude Activity") {
                ForEach(activity.prefix(5)) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: entry.kind == .denied ? "hand.raised" : "eye")
                            .foregroundStyle(entry.kind == .denied ? .orange : .secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.summary)
                            if !entry.detail.isEmpty {
                                Text(entry.detail.replacingOccurrences(of: "\n", with: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(entry.date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    Form {
        ClaudePermissionsSection()
        ClaudeRecentActivitySection()
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 600)
    .previewEnvironment()
}
