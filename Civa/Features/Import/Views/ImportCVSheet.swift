//
//  ImportCVSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Review what Civa found in a CV before it goes into the Career Profile (FR-020). The CV's text
/// stays on the left for reference; everything found is editable, and is added as Needs Review.
struct ImportCVSheet: View {
    let url: URL

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
                    "Civa Couldn't Read This CV",
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
                Text("Text From \(url.lastPathComponent)")
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
                                ImportItemFields(item: $draft.items[index])
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
            sourceText = try CVTextExtractor.text(from: url)
            var draft = CVParser.parse(sourceText)
            draft.markDuplicates(of: existingKeys)
            self.draft = draft
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Records already in the profile, keyed the way imported items are.
    private var existingKeys: Set<String> {
        var keys: Set<String> = []
        for experience in experiences {
            let category: ImportCategory = experience.kind == .professional ? .experience : .organizational
            keys.insert(ImportDraft.key(category, experience.role, experience.organization))
        }
        education.forEach { keys.insert(ImportDraft.key(.education, $0.degree, $0.institution)) }
        projects.forEach { keys.insert(ImportDraft.key(.projects, $0.name, $0.role)) }
        achievements.forEach { keys.insert(ImportDraft.key(.achievements, $0.title, $0.issuer)) }
        certifications.forEach { keys.insert(ImportDraft.key(.certifications, $0.name, $0.issuer)) }
        skills.forEach { keys.insert(ImportDraft.key(.skills, $0.name, "")) }
        return keys
    }

    private func add() {
        draft.add(to: context, existing: personalInfo.first)
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

/// One found entry: checkbox, then its fields while it's checked.
private struct ImportItemFields: View {
    @Binding var item: ImportItem

    var body: some View {
        Toggle(isOn: $item.isIncluded) {
            HStack {
                Text(item.title.isBlank ? String(localized: "Untitled") : item.title)
                    .fontWeight(.medium)
                ImportTag(item: item)
            }
        }
        .toggleStyle(.checkbox)
        if item.isIncluded {
            Picker("Category", selection: $item.category) {
                ForEach(ImportCategory.allCases.filter { $0 != .skills }) { Text($0.title).tag($0) }
            }
            TextField(item.category.titleLabel, text: $item.title)
            TextField(item.category.subtitleLabel, text: $item.subtitle)
            if [.experience, .organizational, .education].contains(item.category) {
                TextField("Location", text: $item.location)
            }
            if item.category == .achievements || item.category == .certifications {
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

/// "Already in Profile" or "Check", when either applies.
private struct ImportTag: View {
    let item: ImportItem

    var body: some View {
        if item.isDuplicate {
            tag(String(localized: "Already in Profile"), color: .secondary)
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
    ImportCVSheet(url: URL(filePath: "/tmp/missing.pdf"))
        .previewEnvironment()
}
