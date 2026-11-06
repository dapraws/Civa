//
//  ImportReviewSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// What to import, and how to read it.
struct ImportRequest: Identifiable {
    enum Kind {
        /// A PDF or Word CV (FR-020).
        case cv
        /// LinkedIn's data export, as a ZIP or its unzipped folder (FR-021).
        case linkedInExport
    }

    let url: URL
    let kind: Kind
    var id: URL { url }
}

/// Review what Civa found before it goes into the Career Profile (FR-020, FR-021). What was read
/// stays on the left for reference; everything found is editable, and is added as Needs Review.
struct ImportReviewSheet: View {
    let request: ImportRequest
    private var url: URL { request.url }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    @Query private var personalInfo: [PersonalInfo]
    @Query private var experiences: [Experience]
    @Query private var education: [Education]
    @Query private var projects: [Project]
    @Query private var achievements: [Achievement]
    @Query private var certifications: [Certification]
    @Query private var skills: [Skill]

    @State private var sourceText = ""
    @State private var draft = ImportDraft()
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var isLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                ContentUnavailableView(
                    "Civa Couldn't Read This File",
                    systemImage: "doc.questionmark",
                    description: Text(loadError)
                )
                Divider()
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding()
            } else {
                HStack(spacing: 0) {
                    source
                        .frame(width: 320)
                    Divider()
                    review
                }
                Divider()
                actions
            }
        }
        .frame(width: 1000, height: 600)
        .onAppear(perform: load)
        .alert(
            "Civa Couldn't Add These Records",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var source: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(request.kind == .cv ? "Text From \(url.lastPathComponent)" : "Read From \(url.lastPathComponent)")
                    .font(.headline)
                Text(sourceText)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(.background.secondary)
    }

    private var review: some View {
        Form {
            personalSection
            ForEach(ImportCategory.allCases) { category in
                let indices = draft.items.indices.filter { draft.items[$0].category == category }
                if !indices.isEmpty {
                    if category == .skills {
                        Section {
                            ForEach(indices, id: \.self) { SkillRow(item: $draft.items[$0]) }
                        } header: {
                            categoryHeader(category, count: indices.count)
                        }
                    } else {
                        ForEach(indices, id: \.self) { index in
                            Section {
                                ImportItemFields(
                                    item: $draft.items[index],
                                    existing: draft.items[index].matchID.flatMap { draft.existing[$0] },
                                    sourceName: url.lastPathComponent
                                )
                            } header: {
                                if index == indices.first { categoryHeader(category, count: indices.count) }
                            }
                        }
                    }
                }
            }
            if !draft.unsorted.isEmpty {
                Section {
                    ForEach(draft.unsorted.indices, id: \.self) { index in
                        Text(draft.unsorted[index])
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Not Sorted")
                } footer: {
                    Text("Lines Civa couldn't place. They aren't added; copy anything you need into your profile.")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var personalSection: some View {
        if !draft.personal.isEmpty {
            Section {
                Toggle("Add Personal Information", isOn: $draft.personal.isIncluded)
                if draft.personal.isIncluded {
                    TextField("Full Name", text: $draft.personal.fullName)
                    TextField("Headline", text: $draft.personal.headline)
                    TextField("Email", text: $draft.personal.email)
                    TextField("Phone", text: $draft.personal.phone)
                    TextField("Location", text: $draft.personal.location)
                    PairListEditor(
                        items: $draft.personal.links,
                        first: \.label,
                        second: \.url,
                        prompts: (String(localized: "Label"), String(localized: "URL")),
                        addTitle: String(localized: "Add Link"),
                        makeItem: { ProfileLink(label: "", url: "") }
                    )
                }
            } header: {
                Text("Personal Information")
            } footer: {
                if personalInfo.first != nil {
                    Text("You already have Personal Information. Only its empty fields are filled; nothing is overwritten.")
                }
            }
        }
    }

    private func categoryHeader(_ category: ImportCategory, count: Int) -> some View {
        Text("\(category.title) (\(count))")
    }

    private var actions: some View {
        HStack {
            Text("Everything is added as Needs Review. Confirm each record in your Career Profile.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Add \(draft.includedCount) to Career Profile", action: add)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.includedCount == 0)
        }
        .padding()
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            var draft: ImportDraft
            switch request.kind {
            case .cv:
                sourceText = try CVTextExtractor.text(from: url)
                draft = CVParser.parse(sourceText)
            case .linkedInExport:
                let files = try LinkedInExport.files(at: url)
                sourceText = files.keys.sorted().map { "• \($0)" }.joined(separator: "\n")
                    + "\n\n" + String(localized: "Only these profile files are read. Connections, messages, and the rest of the export are left untouched.")
                draft = LinkedInExport.draft(from: files)
            }
            draft.match(against: existingRecords.map(\.importItem))
            self.draft = draft
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Profile records an imported item can match.
    private var existingRecords: [any ImportableRecord] {
        experiences as [any ImportableRecord] + education + projects + achievements + certifications + skills
    }

    private func add() {
        let records = Dictionary(existingRecords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        draft.add(to: context, existing: personalInfo.first, records: records, source: RecordSource(name: url.lastPathComponent, date: .now))
        do {
            try context.save()
            dismiss()
            navigation.section = .careerProfile
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

/// One found entry. New ones have a checkbox; ones matching the profile choose Merge, Add as
/// Separate, or Skip, and merging shows the differences to choose from (FR-024).
private struct ImportItemFields: View {
    @Binding var item: ImportItem
    let existing: ImportItem?
    let sourceName: String

    var body: some View {
        if let existing {
            HStack {
                Text(item.title.isBlank ? String(localized: "Untitled") : item.title)
                    .fontWeight(.medium)
                ImportTag(item: item)
                Spacer()
                Picker("Action", selection: $item.action) {
                    Text("Merge").tag(ImportAction.merge)
                    Text("Add as Separate").tag(ImportAction.add)
                    Text("Skip").tag(ImportAction.skip)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            switch item.action {
            case .merge:
                CompareFields(
                    existing: existing,
                    incoming: item,
                    picks: $item.picks,
                    incomingTitle: String(localized: "From \(sourceName)")
                )
            case .add:
                Text("Added as its own record and marked as a possible duplicate of “\(existing.title)”, so you can compare them later.")
                    .foregroundStyle(.secondary)
                editableFields
            case .skip:
                EmptyView()
            }
        } else {
            Toggle(isOn: $item.isIncluded) {
                HStack {
                    Text(item.title.isBlank ? String(localized: "Untitled") : item.title)
                        .fontWeight(.medium)
                    ImportTag(item: item)
                }
            }
            .toggleStyle(.checkbox)
            if item.isIncluded { editableFields }
        }
    }

    @ViewBuilder
    private var editableFields: some View {
        Picker("Category", selection: $item.category) {
            ForEach(ImportCategory.allCases.filter { $0 != .skills }) { Text($0.title).tag($0) }
        }
        TextField(item.category.titleLabel, text: $item.title)
        TextField(item.category.subtitleLabel, text: $item.subtitle)
        if item.category == .experience {
            Picker("Employment Type", selection: $item.employmentType) {
                Text("Not Set").tag(EmploymentType?.none)
                ForEach(EmploymentType.allCases) { Text($0.title).tag(EmploymentType?.some($0)) }
            }
        }
        if [.experience, .organizational, .education].contains(item.category) {
            TextField("Location", text: $item.location)
        }
        if item.category.isSingleDate {
            YearMonthField(title: String(localized: "Date"), value: $item.start)
        } else {
            YearMonthField(title: String(localized: "Start"), value: $item.start)
            Toggle("Ongoing", isOn: $item.isCurrent)
            if !item.isCurrent {
                YearMonthField(title: String(localized: "End"), value: $item.end)
            }
        }
        StringListEditor(
            items: $item.bullets,
            prompt: String(localized: "Detail or result"),
            addTitle: String(localized: "Add Line")
        )
    }
}

/// A found skill on one row.
private struct SkillRow: View {
    @Binding var item: ImportItem

    var body: some View {
        HStack {
            Toggle("Add skill", isOn: $item.isIncluded)
                .toggleStyle(.checkbox)
                .labelsHidden()
            TextField("Skill", text: $item.title)
                .labelsHidden()
            TextField("Category", text: $item.subtitle, prompt: Text("Category"))
                .labelsHidden()
                .frame(maxWidth: 180)
            ImportTag(item: item)
        }
    }
}

/// "Already in Profile", "Matches Your Profile", or "Check", when one applies.
private struct ImportTag: View {
    let item: ImportItem

    var body: some View {
        if item.isIdentical {
            tag(String(localized: "Already in Profile"), color: .secondary)
        } else if item.matchID != nil {
            tag(String(localized: "Matches Your Profile"), color: .orange)
        } else if item.needsCheck {
            tag(String(localized: "Check"), color: .orange)
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: .capsule)
    }
}

#Preview {
    ImportReviewSheet(request: ImportRequest(url: URL(filePath: "/tmp/missing.pdf"), kind: .cv))
        .previewEnvironment()
}
