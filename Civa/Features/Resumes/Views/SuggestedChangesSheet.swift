//
//  SuggestedChangesSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Career Profile changes this resume doesn't have yet. Each one is applied or kept as is by the
/// user; applied ones are unsaved edits like any other, so Revert still undoes them (FR-042).
struct SuggestedChangesSheet: View {
    @Binding var document: ResumeDocument
    let source: ProfileSource

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let suggestions = SuggestedChanges.suggestions(for: document, from: source)
        VStack(spacing: 0) {
            if suggestions.isEmpty {
                ContentUnavailableView(
                    "Up to Date",
                    systemImage: "checkmark.circle",
                    description: Text("This resume has every change from your Career Profile, or you chose to keep it as is.")
                )
            } else {
                Form {
                    ForEach(suggestions) { suggestion in
                        Section {
                            ForEach(suggestion.changes, id: \.self, content: changeRow)
                            HStack {
                                Spacer()
                                Button(suggestion.target.isRemoval ? "Keep Entry" : "Keep Resume as Is") {
                                    SuggestedChanges.dismiss(suggestion, in: &document, from: source)
                                }
                                Button(suggestion.target.isRemoval ? "Remove Entry" : "Apply") {
                                    SuggestedChanges.apply(suggestion, to: &document, from: source)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } header: {
                            Text(suggestion.title)
                        }
                    }
                }
                .formStyle(.grouped)
            }

            Divider()
            HStack {
                Text("Applied changes stay unsaved until you save the resume.")
                    .foregroundStyle(.secondary)
                Spacer()
                if suggestions.count > 1 {
                    Button("Apply All") {
                        for suggestion in suggestions { SuggestedChanges.apply(suggestion, to: &document, from: source) }
                    }
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 640, height: 520)
    }

    private func changeRow(_ change: ResumeSuggestion.Change) -> some View {
        LabeledContent(change.label) {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    if !change.old.isEmpty {
                        Text(change.old)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                    if !change.old.isEmpty, !change.new.isEmpty {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                    }
                    if !change.new.isEmpty {
                        Text(change.new)
                            .foregroundStyle(.green)
                    }
                }
                .multilineTextAlignment(.trailing)
                if change.replacesEdit {
                    Label("Replaces your wording in this resume", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

extension ResumeSuggestion.Target {
    var isRemoval: Bool {
        if case .removedEntry = self { true } else { false }
    }
}

#Preview {
    @Previewable @State var document = ResumeDocument.blank
    SuggestedChangesSheet(document: $document, source: ProfileSource(person: nil, records: []))
}
