//
//  ApplicationsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Job application tracking (FR-060 to FR-062), filterable by status.
struct ApplicationsView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    /// nil shows every status.
    @State private var status: ApplicationStatus?
    /// The filter picked while the unsaved-changes prompt is up.
    @State private var pendingStatus: ApplicationStatus??

    var body: some View {
        ApplicationList(status: status)
            .id(status)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Picker("Status", selection: changes.selection($status, pending: $pendingStatus)) {
                        Text("All Statuses").tag(ApplicationStatus?.none)
                        Divider()
                        ForEach(ApplicationStatus.allCases) { status in
                            Text(status.title).tag(ApplicationStatus?.some(status))
                        }
                    }
                    .help("Show applications with this status")
                }
            }
    }
}

struct ApplicationList: View {
    let status: ApplicationStatus?

    var body: some View {
        RecordListDetail(
            addTitle: String(localized: "Add Application"),
            empty: status == nil
                ? .init(
                    title: String(localized: "No Applications Yet"),
                    message: String(localized: "Track the jobs you're interested in and where each one stands."),
                    systemImage: "tray"
                )
                : .init(
                    title: String(localized: "No Applications Here"),
                    message: String(localized: "None of your applications have this status."),
                    systemImage: "line.3.horizontal.decrease.circle"
                ),
            filter: JobApplication.withStatus(status),
            order: { ($0.applicationDate ?? .distantFuture) > ($1.applicationDate ?? .distantFuture) },
            subtitle: { application in
                [
                    application.company,
                    application.status.title,
                    application.applicationDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                ]
                .filter { !$0.isBlank }
                .joined(separator: " · ")
            },
            makeRecord: { JobApplication(company: "", position: "", status: status ?? .wishlist) },
            editor: { ApplicationForm(editor: $0) }
        )
    }
}

struct ApplicationForm: View {
    let editor: RecordEditor<JobApplication>

    var body: some View {
        Form {
            Section {
                TextField("Position", text: editor.binding(\.position), prompt: Text("Required"))
                FieldError(editor.error(for: \.position))
                TextField("Company", text: editor.binding(\.company), prompt: Text("Required"))
                FieldError(editor.error(for: \.company))
                Picker("Status", selection: editor.binding(\.status)) {
                    ForEach(ApplicationStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
            }
            Section {
                Toggle("Applied on a Date", isOn: hasDate)
                if let date = editor.record.applicationDate {
                    DatePicker(
                        "Application Date",
                        selection: Binding(get: { date }, set: { editor.binding(\.applicationDate).wrappedValue = $0 }),
                        displayedComponents: .date
                    )
                }
            }
            Section("Job Description") {
                TextField(
                    "Job Description",
                    text: editor.binding(\.jobDescription),
                    prompt: Text("Paste the job description"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(6...24)
            }
        }
        .formStyle(.grouped)
    }

    /// Turning the date on starts at today; turning it off clears it.
    private var hasDate: Binding<Bool> {
        Binding(
            get: { editor.record.applicationDate != nil },
            set: { editor.binding(\.applicationDate).wrappedValue = $0 ? Calendar.current.startOfDay(for: .now) : nil }
        )
    }
}

#Preview("Applications") {
    NavigationStack {
        ApplicationsView()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    ApplicationForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
