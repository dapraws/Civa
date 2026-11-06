//
//  ResumesView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Resume versions as a gallery (FR-041): each one is edited independently.
struct ResumesView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var isPickingFromProfile = false

    var body: some View {
        RecordGallery(
            title: String(localized: "Resumes"),
            addTitle: String(localized: "New Resume"),
            empty: .init(
                title: String(localized: "No Resumes Yet"),
                message: String(localized: "Create a resume and see it as an ATS-friendly PDF while you edit."),
                systemImage: AppSection.resumes.systemImage
            ),
            order: { $0.updatedAt > $1.updatedAt },
            cardWidth: 180,
            makeRecord: { Resume(title: "") },
            duplicate: { resume in
                Resume(
                    title: String(localized: "\(resume.displayTitle) Copy"),
                    targetPosition: resume.targetPosition,
                    jobDescription: resume.jobDescription,
                    document: resume.document
                )
            },
            card: { ResumeCard(resume: $0) },
            editor: { ResumeEditorView(editor: $0) }
        )
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
}

#Preview {
    NavigationStack {
        ResumesView()
    }
    .frame(width: 1200, height: 700)
    .previewEnvironment()
}
