//
//  ResumeHistorySheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// A resume's versions: what changed since each one, both side by side, and restoring (FR-043).
struct ResumeHistorySheet: View {
    let editor: RecordEditor<Resume>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ResumeSnapshot.ID?
    @State private var isNamingCheckpoint = false
    @State private var checkpointName = ""
    @State private var isConfirmingRestore = false
    @State private var storeError: String?

    var body: some View {
        let history = editor.record.history
        let selected = history.first { $0.id == selection }
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                list(history)
                    .frame(width: 230)
                Divider()
                if let selected {
                    detail(selected)
                } else {
                    ContentUnavailableView(
                        "Choose a Version",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Civa saves a version when you create or export this resume, and when you save a checkpoint.")
                    )
                }
            }
            Divider()
            HStack {
                Button("Save Checkpoint…", systemImage: "bookmark") {
                    checkpointName = ""
                    isNamingCheckpoint = true
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 980, height: 660)
        .onAppear { selection = history.first?.id }
        .alert("Save Checkpoint", isPresented: $isNamingCheckpoint) {
            TextField("Name", text: $checkpointName, prompt: Text("Before cutting projects"))
            Button("Save", action: saveCheckpoint)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves your changes and keeps this version in History.")
        }
        .confirmationDialog("Restore this version?", isPresented: $isConfirmingRestore) {
            Button("Restore", role: .destructive) { if let selected { restore(selected) } }
        } message: {
            Text("Your unsaved changes will be replaced. Your last saved version stays in History.")
        }
        .alert(
            "Civa Couldn't Update History",
            isPresented: Binding(get: { storeError != nil }, set: { if !$0 { storeError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(storeError ?? "")
        }
    }

    private func list(_ history: [ResumeSnapshot]) -> some View {
        let days = Dictionary(grouping: history) { Calendar.current.startOfDay(for: $0.createdAt) }
        return List(selection: $selection) {
            ForEach(days.keys.sorted(by: >), id: \.self) { day in
                Section(dayTitle(day)) {
                    ForEach(days[day] ?? []) { snapshot in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(snapshot.createdAt, format: .dateTime.hour().minute())
                                Spacer()
                                Text(snapshot.reason.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !snapshot.name.isBlank {
                                Text(snapshot.name)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tag(snapshot.id)
                    }
                }
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func detail(_ snapshot: ResumeSnapshot) -> some View {
        let old = snapshot.document
        let current = editor.record.document
        let changes = ResumeDiff.changes(from: old, to: current)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Changed Since This Version")
                .font(.headline)
            if changes.isEmpty {
                Text("Nothing. This version matches the current resume.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(changes, id: \.self) { change in
                            Label(change.text, systemImage: change.systemImage)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)
            }
            HStack(spacing: 12) {
                preview(String(localized: "This Version"), old)
                preview(editor.isDirty ? String(localized: "Current (Unsaved)") : String(localized: "Current"), current)
            }
            HStack {
                Button("Delete Version", role: .destructive) { delete(snapshot) }
                Spacer()
                Button("Restore This Version") {
                    if editor.isDirty { isConfirmingRestore = true } else { restore(snapshot) }
                }
                .disabled(changes.isEmpty)
            }
        }
        .padding()
    }

    private func preview(_ title: String, _ document: ResumeDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            PDFPreview(data: ResumeRenderer.pdf(for: document))
                .clipShape(.rect(cornerRadius: 6))
        }
    }

    /// The old version becomes unsaved changes to review, then Save or Revert. The saved version it
    /// replaces is kept first; Revert drops that along with the restore, since nothing was replaced.
    private func restore(_ snapshot: ResumeSnapshot) {
        let document = snapshot.document
        if editor.isDirty { editor.discard() }
        editor.update { $0.recordSnapshot(.beforeRestore, in: context) }
        editor.binding(\.document).wrappedValue = document
        dismiss()
    }

    private func saveCheckpoint() {
        editor.update { $0.recordSnapshot(.checkpoint, name: checkpointName.trimmingCharacters(in: .whitespaces), in: context) }
        if !editor.save() {
            storeError = editor.storeError ?? String(localized: "Fix the highlighted fields, then save again.")
            editor.storeError = nil
        }
        selection = editor.record.history.first?.id
    }

    /// Saved right away unless the resume has unsaved changes; then it's saved, or reverted, with them.
    private func delete(_ snapshot: ResumeSnapshot) {
        context.delete(snapshot)
        if editor.isDirty {
            editor.update { _ in }
        } else {
            do {
                try context.save()
            } catch {
                context.rollback()
                storeError = error.localizedDescription
            }
        }
        selection = editor.record.history.first { $0.id != snapshot.id }?.id
    }
}

#Preview {
    ResumeHistorySheet(editor: .preview())
        .previewEnvironment()
}
