//
//  DuplicateMergeSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Compare a possible duplicate with the record it may repeat, then merge it in or keep both (FR-024).
struct DuplicateMergeSheet: View {
    let duplicate: any ImportableRecord
    /// Called before the duplicate is deleted, so its editor closes first.
    let onMerged: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @State private var original: (any ImportableRecord)?
    @State private var picks: Set<ImportField> = []
    @State private var storeError: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if let original {
                    Section {
                        CompareFields(
                            existing: original.importItem,
                            incoming: duplicate.importItem,
                            picks: $picks,
                            incomingTitle: String(localized: "This Record")
                        )
                    } header: {
                        Text("Compare With “\(original.displayTitle)”")
                    } footer: {
                        Text("Merge copies the values you pick and any new details into “\(original.displayTitle)”, then deletes this record. Keep Both marks them as different.")
                    }
                } else {
                    Text("The record this may repeat has been deleted. Keep this one to clear the flag.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Keep Both", action: keepBoth)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge", action: merge)
                    .keyboardShortcut(.defaultAction)
                    .disabled(original == nil)
            }
            .padding()
        }
        .frame(width: 620, height: 440)
        .onAppear {
            original = findOriginal(of: duplicate)
            if let original {
                picks = Set(ImportMatcher.differences(duplicate.importItem, original.importItem).filter {
                    original.importItem.display($0).isBlank
                })
            }
        }
        .alert(
            "Civa Couldn't Save Your Changes",
            isPresented: Binding(get: { storeError != nil }, set: { if !$0 { storeError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(storeError ?? "")
        }
    }

    // ponytail: fetches every record of the type to find one; fine at profile sizes.
    private func findOriginal<M: ImportableRecord>(of record: M) -> (any ImportableRecord)? {
        guard let id = record.possibleDuplicateOf else { return nil }
        return (try? context.fetch(FetchDescriptor<M>()))?.first { $0.id == id }
    }

    private func merge() {
        guard let original else { return }
        original.merge(duplicate.importItem, fields: picks, source: nil)
        duplicate.sources.forEach(original.addSource)
        let originalID = original.id
        onMerged()
        context.delete(duplicate)
        save()
        navigation.recordToOpen = originalID
    }

    private func keepBoth() {
        duplicate.possibleDuplicateOf = nil
        save()
    }

    private func save() {
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            storeError = error.localizedDescription
        }
    }
}
