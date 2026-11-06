//
//  ResumesView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Resume versions (FR-041): each one is edited independently.
struct ResumesView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var isPickingFromProfile = false

    var body: some View {
        list
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New from Career Profile…", systemImage: "person.text.rectangle") {
                        changes.perform { isPickingFromProfile = true }
                    }
                    .help("New resume from your Career Profile")
                }
            }
            .sheet(isPresented: $isPickingFromProfile) {
                NewResumeFromProfileSheet()
            }
    }

    private var list: some View {
        RecordListDetail(
            addTitle: String(localized: "New Resume"),
            empty: .init(
                title: String(localized: "No Resumes Yet"),
                message: String(localized: "Create a resume and see it as an ATS-friendly PDF while you edit."),
                systemImage: AppSection.resumes.systemImage
            ),
            order: { $0.updatedAt > $1.updatedAt },
            subtitle: { resume in
                resume.targetPosition.isBlank
                    ? resume.updatedAt.formatted(date: .abbreviated, time: .omitted)
                    : resume.targetPosition
            },
            makeRecord: { Resume(title: "") },
            editor: { ResumeEditorView(editor: $0) }
        )
    }
}

#Preview {
    NavigationStack {
        ResumesView()
    }
    .frame(width: 1200, height: 700)
    .previewEnvironment()
}
