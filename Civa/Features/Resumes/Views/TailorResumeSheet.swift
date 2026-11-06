//
//  TailorResumeSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Start a tailored resume as a copy of the Master Resume (FR-040, FR-041), optionally for an application.
struct TailorResumeSheet: View {
    let master: Resume

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \JobApplication.createdAt, order: .reverse) private var applications: [JobApplication]

    @State private var title = ""
    @State private var targetPosition = ""
    @State private var jobDescription = ""
    @State private var application: JobApplication?
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Resume Name", text: $title, prompt: Text("Grab Application"))
                    TextField("Target Position", text: $targetPosition, prompt: Text("Senior iOS Engineer"))
                    Picker("For Application", selection: $application) {
                        Text("None").tag(JobApplication?.none)
                        if !applications.isEmpty { Divider() }
                        ForEach(applications) { application in
                            Text("\(application.displayTitle) · \(application.company)").tag(JobApplication?.some(application))
                        }
                    }
                } footer: {
                    Text("Starts as a copy of “\(master.displayTitle)”. Later changes to either one don't affect the other.")
                }
                Section("Job Description") {
                    TextField(
                        "Job Description",
                        text: $jobDescription,
                        prompt: Text("Paste the job description"),
                        axis: .vertical
                    )
                    .labelsHidden()
                    .lineLimit(6...12)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Resume", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isBlank)
            }
            .padding()
        }
        .frame(width: 520, height: 520)
        .onChange(of: application) { _, application in
            // Picking an application fills in what's still empty.
            guard let application else { return }
            if title.isBlank { title = String(localized: "\(application.company) Application") }
            if targetPosition.isBlank { targetPosition = application.position }
            if jobDescription.isBlank { jobDescription = application.jobDescription }
        }
        .alert(
            "Civa Couldn't Create the Resume",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func create() {
        let resume = master.tailoredCopy(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            targetPosition: targetPosition.trimmingCharacters(in: .whitespacesAndNewlines),
            jobDescription: jobDescription
        )
        context.insert(resume)
        application?.resume = resume
        do {
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
    TailorResumeSheet(master: Resume(title: "Master Resume"))
        .previewEnvironment()
}
