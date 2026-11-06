//
//  NewResumeFromProfileSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Pick Career Profile records for a new resume (FR-031). Only chosen records go in, and records
/// that need review can't be chosen until they're confirmed (FR-015).
struct NewResumeFromProfileSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    @Query private var personalInfo: [PersonalInfo]
    @Query private var experiences: [Experience]
    @Query private var education: [Education]
    @Query private var projects: [Project]
    @Query private var achievements: [Achievement]
    @Query private var certifications: [Certification]
    @Query(sort: \Skill.name) private var skills: [Skill]
    @Query(filter: #Predicate<Resume> { $0.isMaster }) private var masters: [Resume]

    @State private var title = ""
    @State private var includesPersonalInfo = true
    @State private var selected: Set<UUID> = []
    /// On by default when there's no Master Resume yet.
    @State private var makesMaster: Bool?
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Resume Name", text: $title, prompt: Text("iOS Developer Resume"))
                    Toggle("Make This My Master Resume", isOn: Binding(
                        get: { makesMaster ?? masters.isEmpty },
                        set: { makesMaster = $0 }
                    ))
                } footer: {
                    if (makesMaster ?? masters.isEmpty), let master = masters.first {
                        Text("“\(master.displayTitle)” will become a tailored resume.")
                    } else {
                        Text("Tailored resumes start as a copy of your Master Resume.")
                    }
                }
                if let person = personalInfo.first {
                    Section("Personal Information") {
                        Toggle(isOn: $includesPersonalInfo) {
                            RecordRow(title: person.displayTitle, subtitle: person.email, needsReview: person.needsReview)
                        }
                        .disabled(person.needsReview)
                    }
                }
                picker(ProfileCategory.professional.title, experiences.filter { $0.kind == .professional }) {
                    [$0.organization, YearMonth.rangeText(start: $0.start, end: $0.end, isCurrent: $0.isCurrent)]
                }
                picker(ProfileCategory.organizational.title, experiences.filter { $0.kind == .organizational }) {
                    [$0.organization, YearMonth.rangeText(start: $0.start, end: $0.end, isCurrent: $0.isCurrent)]
                }
                picker(ProfileCategory.education.title, education) {
                    [$0.degree, YearMonth.rangeText(start: $0.start, end: $0.end)]
                }
                picker(ProfileCategory.projects.title, projects) {
                    [$0.role, YearMonth.rangeText(start: $0.start, end: $0.end)]
                }
                picker(String(localized: "Achievements"), achievements) { [$0.issuer] }
                picker(String(localized: "Certifications"), certifications) { [$0.issuer] }
                picker(String(localized: "Skills"), skills) { [$0.category] }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text("\(selected.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Resume", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isBlank)
            }
            .padding()
        }
        .frame(width: 560, height: 640)
        .alert(
            "Civa Couldn't Create the Resume",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private func picker<M: ProfileRecord>(
        _ heading: String,
        _ records: [M],
        details: @escaping (M) -> [String]
    ) -> some View where M.ID == UUID {
        if !records.isEmpty {
            let choosable = records.filter { !$0.needsReview }.map(\.id)
            let allChosen = !choosable.isEmpty && choosable.allSatisfy(selected.contains)
            Section {
                ForEach(records) { record in
                    Toggle(isOn: chosen(record.id)) {
                        RecordRow(
                            title: record.displayTitle,
                            subtitle: details(record).filter { !$0.isBlank }.joined(separator: " · "),
                            needsReview: record.needsReview
                        )
                    }
                    .disabled(record.needsReview)
                }
            } header: {
                HStack {
                    Text(heading)
                    Spacer()
                    Button(allChosen ? "Deselect All" : "Select All") {
                        if allChosen { selected.subtract(choosable) } else { selected.formUnion(choosable) }
                    }
                    .buttonStyle(.link)
                    .disabled(choosable.isEmpty)
                }
            } footer: {
                if records.contains(where: \.needsReview) {
                    Text("Confirm records that need review in Career Profile before adding them to a resume.")
                }
            }
        }
    }

    private func chosen(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { if $0 { selected.insert(id) } else { selected.remove(id) } }
        )
    }

    private func create() {
        let selection = ResumeBuilder.Selection(
            personalInfo: includesPersonalInfo ? personalInfo.first : nil,
            experiences: experiences.filter { selected.contains($0.id) },
            education: education.filter { selected.contains($0.id) },
            projects: projects.filter { selected.contains($0.id) },
            achievements: achievements.filter { selected.contains($0.id) },
            certifications: certifications.filter { selected.contains($0.id) },
            skills: skills.filter { selected.contains($0.id) }
        )
        let resume = Resume(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            document: ResumeBuilder.document(from: selection)
        )
        context.insert(resume)
        do {
            if makesMaster ?? masters.isEmpty { try Resume.makeMaster(resume, in: context) }
            try context.save()
            navigation.recordToOpen = resume.id
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NewResumeFromProfileSheet()
        .previewEnvironment()
}
