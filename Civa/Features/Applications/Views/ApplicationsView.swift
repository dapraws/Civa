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

/// An application in the gallery: logo, status, position, company, and date.
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
            Text(application.applicationDate.map { String(localized: "Applied \($0.formatted(date: .abbreviated, time: .omitted))") }
                ?? String(localized: "Not applied yet"))
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                    StatusPill(status: editor.record.status)
                }
                .padding(.vertical, 4)
            }
            Section {
                TextField("Position", text: editor.binding(\.position), prompt: Text("Required"))
                FieldError(editor.error(for: \.position))
                OrganizationField(title: "Company", name: editor.binding(\.company), prompt: Text("Required"))
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
