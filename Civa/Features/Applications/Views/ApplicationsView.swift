//
//  ApplicationsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
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
                ToolbarItem(placement: .primaryAction) {
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
        RecordGallery(
            title: String(localized: "Applications"),
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
            cardWidth: 220,
            makeRecord: { JobApplication(company: "", position: "", status: status ?? .wishlist) },
            card: { ApplicationCard(application: $0) },
            editor: { ApplicationForm(editor: $0) }
        )
    }
}

/// An application in the gallery: logo, status, position, company, date, and the resume sent.
struct ApplicationCard: View {
    let application: JobApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                OrganizationLogo(name: application.company, size: 44)
                Spacer()
                StatusPill(status: application.status)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(application.position.isBlank ? String(localized: "New Application") : application.position)
                    .font(.headline)
                    .lineLimit(1)
                Text(application.company)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(application.applicationDate.map { String(localized: "Applied \($0.formatted(date: .abbreviated, time: .omitted))") }
                    ?? String(localized: "Not applied yet"))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                Spacer(minLength: 0)
                if !application.documents.isEmpty {
                    Label("\(application.documents.count)", systemImage: "paperclip")
                        .foregroundStyle(.secondary)
                        .help("Documents attached")
                        .accessibilityLabel("^[\(application.documents.count) document](inflect: true)")
                        .fixedSize()
                }
                if let resume = application.resume {
                    Label(resume.displayTitle, systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.separator)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .accessibilityElement(children: .combine)
    }
}

struct StatusPill: View {
    let status: ApplicationStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.15), in: .capsule)
    }
}

extension ApplicationStatus {
    var color: Color {
        switch self {
        case .wishlist: .gray
        case .applied: .blue
        case .interview: .purple
        case .assessment: .orange
        case .offer: .green
        case .rejected: .red
        case .withdrawn: .brown
        }
    }
}

struct ApplicationForm: View {
    let editor: RecordEditor<JobApplication>

    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \Resume.updatedAt, order: .reverse) private var resumes: [Resume]

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    OrganizationLogo(name: editor.record.company, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editor.record.displayTitle)
                            .font(.title3.weight(.semibold))
                        Text(editor.record.company)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // The status lives here, in its color, instead of repeating as a row below.
                    Picker("Status", selection: editor.binding(\.status)) {
                        ForEach(ApplicationStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .tint(editor.record.status.color)
                    .help("Status")
                }
                .padding(.vertical, 4)
            }
            Section {
                TextField("Position", text: editor.binding(\.position), prompt: Text("Required"))
                FieldError(editor.error(for: \.position))
                OrganizationField(title: "Company", name: editor.binding(\.company), prompt: Text("Required"))
                FieldError(editor.error(for: \.company))
            }
            Section {
                Picker("Resume", selection: editor.binding(\.resume)) {
                    Text("None").tag(Resume?.none)
                    if !resumes.isEmpty { Divider() }
                    ForEach(resumes) { resume in
                        Text(resume.displayTitle).tag(Resume?.some(resume))
                    }
                }
                if let resume = editor.record.resume {
                    Button("Open Resume") {
                        changes.perform {
                            navigation.recordToOpen = resume.id
                            navigation.section = .resumes
                        }
                    }
                }
                AskClaudeButton(
                    title: "Draft a Resume with Claude",
                    ask: .init(kind: .draftResume, category: .resumes, targetID: editor.record.id, targetTitle: editor.record.displayTitle),
                    unavailable: ClaudeAsk.unavailable(
                        missing: editor.record.jobDescription.isBlank ? String(localized: "Add the job description first.") : nil
                    ),
                    tip: .draft,
                    saveFirst: editor.saveIfNeeded
                )
            } footer: {
                Text("The resume you sent for this job. Claude can draft one from your Career Profile for this job description; you keep or discard it.")
            }
            Section {
                Toggle("Date Applied", isOn: hasDate)
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
            DocumentsSection(editor: editor)
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

#Preview("Card") {
    ApplicationCard(application: JobApplication(company: "Apple", position: "iOS Engineer", applicationDate: .now, status: .interview))
        .frame(width: 240)
        .padding()
        .previewEnvironment()
}

#Preview("Form") {
    ApplicationForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
