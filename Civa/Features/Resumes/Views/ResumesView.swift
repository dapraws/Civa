//
//  ResumesView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Resume versions as a gallery: the Master Resume first (FR-040), then tailored resumes,
/// each edited independently (FR-041).
struct ResumesView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query(filter: #Predicate<Resume> { $0.isMaster }) private var masters: [Resume]
    @State private var isPickingFromProfile = false
    @State private var tailoring: Resume?

    var body: some View {
        RecordGallery(
            title: String(localized: "Resumes"),
            addTitle: String(localized: "New Resume"),
            empty: .init(
                title: String(localized: "No Resumes Yet"),
                message: String(localized: "Create a resume and see it as an ATS-friendly PDF while you edit."),
                systemImage: AppSection.resumes.systemImage
            ),
            order: { ($0.isMaster ? 1 : 0, $0.updatedAt) > ($1.isMaster ? 1 : 0, $1.updatedAt) },
            cardWidth: 180,
            makeRecord: { Resume(title: "") },
            duplicate: { resume in
                resume.tailoredCopy(
                    title: String(localized: "\(resume.displayTitle) Copy"),
                    targetPosition: resume.targetPosition,
                    jobDescription: resume.jobDescription
                )
            },
            section: { $0.isMaster ? String(localized: "Master Resume") : String(localized: "Tailored Resumes") },
            actions: [
                GalleryAction(
                    title: { $0.isMaster ? String(localized: "Remove as Master Resume") : String(localized: "Set as Master Resume") },
                    run: { resume, context in try Resume.makeMaster(resume.isMaster ? nil : resume, in: context) }
                ),
            ],
            showsAddButton: false,
            card: { ResumeCard(resume: $0) },
            editor: { ResumeEditorView(editor: $0) }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                newMenu
            }
        }
        .sheet(isPresented: $isPickingFromProfile) {
            NewResumeFromProfileSheet()
        }
        .sheet(item: $tailoring) { master in
            TailorResumeSheet(master: master)
        }
    }

    private var newMenu: some View {
        Menu {
            if let master = masters.first {
                Button("Tailor from Master Resume…", systemImage: "crown") {
                    changes.perform { tailoring = master }
                }
                .keyboardShortcut("n")
            }
            Button("From Career Profile…", systemImage: "person.text.rectangle") {
                changes.perform { isPickingFromProfile = true }
            }
            Button("Blank", systemImage: "doc") {
                changes.perform { navigation.startsNewRecord = true }
            }
            .keyboardShortcut(masters.isEmpty ? KeyboardShortcut("n") : nil)
        } label: {
            Label("New Resume", systemImage: "plus")
        }
        .help("New resume")
    }
}

#Preview {
    NavigationStack {
        ResumesView()
    }
    .frame(width: 1200, height: 700)
    .previewEnvironment()
}
