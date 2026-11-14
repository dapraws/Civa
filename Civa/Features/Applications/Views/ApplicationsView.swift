//
//  ApplicationsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Job application tracking (FR-060 to FR-062): a list plus detail, filterable by status
/// (DESIGN.md §8.7).
struct ApplicationsView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    /// nil shows every status.
    @State private var status: ApplicationStatus?
    /// The filter picked while the unsaved-changes prompt is up.
    @State private var pendingStatus: ApplicationStatus??
    @State private var addAction: PageAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(String(localized: "Applications")) {
                CivaMenuPicker(
                    "Status",
                    selection: changes.selection($status, pending: $pendingStatus),
                    value: Text(status?.title ?? String(localized: "All Statuses"))
                ) {
                    Text("All Statuses").tag(ApplicationStatus?.none)
                    Divider()
                    ForEach(ApplicationStatus.allCases) { status in
                        Text(status.title).tag(ApplicationStatus?.some(status))
                    }
                } label: {
                    if let status { StatusMark(status, emphasized: true) } else { Text("All Statuses") }
                }
                .help("Show applications with this status")
                PageActionButton(action: addAction)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, 20)
            .padding(.bottom, Space.m)
            Rectangle().fill(Color.hairline).frame(height: 1)
            ApplicationList(status: status)
                .id(status)
        }
        .background(Color.canvas)
        .onPreferenceChange(PageActionKey.self) { action in
            MainActor.assumeIsolated { addAction = action }
        }
        .onChange(of: navigation.applicationStatusFilter, initial: true) { _, next in
            guard let next else { return }
            status = next
            navigation.applicationStatusFilter = nil
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
                    title: String(localized: "No applications yet"),
                    message: String(localized: "Track the jobs you're interested in and where each one stands."),
                    systemImage: "tray"
                )
                : .init(
                    title: String(localized: "No applications here"),
                    message: String(localized: "None of your applications have this status."),
                    systemImage: "line.3.horizontal.decrease.circle"
                ),
            filter: JobApplication.withStatus(status),
            order: JobApplication.listOrder,
            subtitle: \.company,
            makeRecord: { JobApplication(company: "", position: "", status: status ?? .wishlist) },
            showsTitle: false,
            row: { application, isSelected in
                AnyView(RecordRow(
                    title: application.position.isBlank ? String(localized: "New Application") : application.position,
                    subtitle: application.company,
                    isSelected: isSelected,
                    status: application.status
                ) {
                    OrganizationLogo(name: application.company, size: 28)
                })
            }
        ) { editor in
            ApplicationForm(editor: editor)
        }
    }
}

struct ApplicationForm: View {
    let editor: RecordEditor<JobApplication>

    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \Resume.updatedAt, order: .reverse) private var resumes: [Resume]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            form
        }
    }

    /// Logo, position, company and status (DESIGN.md §8.7); the form below doesn't repeat them.
    private var header: some View {
        HStack(spacing: Space.m) {
            OrganizationLogo(name: editor.record.company, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(editor.record.displayTitle)
                    .font(.detailTitle)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if !editor.record.company.isBlank {
                    Text(editor.record.company)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Space.l)
            CivaMenuPicker("Status", selection: editor.binding(\.status), value: Text(editor.record.status.title)) {
                ForEach(ApplicationStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            } label: {
                StatusMark(editor.record.status, emphasized: true)
            }
            .help("Status")
        }
        .frame(maxWidth: Size.formMaxWidth, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.top, 20)
        .padding(.bottom, Space.s)
    }

    private var form: some View {
        Form {
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
                    // The resume's first page, as on the Resumes page, so you see which one went out.
                    HStack(alignment: .bottom, spacing: 14) {
                        Button { open(resume) } label: {
                            ResumeCard(resume: resume)
                                .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                        .help("Open this resume")
                        Button("Open Resume") { open(resume) }
                            .civaButton(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
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
            Section(civa: "Job Description") {
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
        .civaForm()
    }

    private func open(_ resume: Resume) {
        changes.perform {
            navigation.recordToOpen = resume.id
            navigation.section = .resumes
        }
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
    ApplicationsView()
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}

#Preview("Form") {
    ApplicationForm(editor: .preview())
        .frame(width: 600, height: 600)
        .previewEnvironment()
}
