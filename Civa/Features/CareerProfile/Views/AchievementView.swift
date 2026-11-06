//
//  AchievementView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

struct AchievementList: View {
    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Achievement"),
            empty: .init(
                title: String(localized: "No Achievements Yet"),
                message: String(localized: "Add awards, rankings, scholarships, and other formal recognition."),
                systemImage: "trophy"
            ),
            order: { ($0.date ?? .distantFuture) > ($1.date ?? .distantFuture) },
            subtitle: { achievement in
                [achievement.issuer, achievement.date?.formatted() ?? ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            },
            makeRecord: { Achievement(title: "") },
            editor: { AchievementForm(editor: $0) }
        )
    }
}

struct AchievementForm: View {
    /// The record an achievement came from, if any (FR-013).
    enum Source: Hashable {
        case none
        case experience(UUID)
        case project(UUID)
        case education(UUID)
    }

    let editor: RecordEditor<Achievement>

    @Query private var experiences: [Experience]
    @Query private var projects: [Project]
    @Query private var education: [Education]

    var body: some View {
        Form {
            ReviewBanner(editor: editor)
            Section {
                TextField("Title", text: editor.binding(\.title), prompt: Text("Required"))
                FieldError(editor.error(for: \.title))
                TextField("Issuer", text: editor.binding(\.issuer), prompt: Text("Who gave it"))
                YearMonthField(title: String(localized: "Date"), value: editor.binding(\.date))
            }
            Section {
                Picker("Related To", selection: source) {
                    Text("Nothing").tag(Source.none)
                    if !experiences.isEmpty {
                        Section("Experience") {
                            ForEach(experiences) { Text(label($0)).tag(Source.experience($0.id)) }
                        }
                    }
                    if !projects.isEmpty {
                        Section("Projects") {
                            ForEach(projects) { Text($0.displayTitle).tag(Source.project($0.id)) }
                        }
                    }
                    if !education.isEmpty {
                        Section("Education") {
                            ForEach(education) { Text($0.displayTitle).tag(Source.education($0.id)) }
                        }
                    }
                }
            } footer: {
                Text("Achievements are formal recognition. Results of your work go in an experience's Impact.")
            }
            Section("Description") {
                TextField(
                    "Description",
                    text: editor.binding(\.details),
                    prompt: Text("What it was for"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(3...10)
            }
            DocumentsSection(editor: editor)
            CustomFieldsSection(fields: editor.binding(\.customFields))
        }
        .formStyle(.grouped)
    }

    private func label(_ experience: Experience) -> String {
        experience.organization.isBlank
            ? experience.displayTitle
            : "\(experience.displayTitle) — \(experience.organization)"
    }

    private var source: Binding<Source> {
        Binding(
            get: {
                let achievement = editor.record
                if let experience = achievement.experience { return .experience(experience.id) }
                if let project = achievement.project { return .project(project.id) }
                if let education = achievement.education { return .education(education.id) }
                return .none
            },
            set: { source in
                editor.update { achievement in
                    achievement.experience = nil
                    achievement.project = nil
                    achievement.education = nil
                    switch source {
                    case .none: break
                    case .experience(let id): achievement.experience = experiences.first { $0.id == id }
                    case .project(let id): achievement.project = projects.first { $0.id == id }
                    case .education(let id): achievement.education = education.first { $0.id == id }
                    }
                }
            }
        )
    }
}

#Preview("List") {
    NavigationStack {
        AchievementList()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    AchievementForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
