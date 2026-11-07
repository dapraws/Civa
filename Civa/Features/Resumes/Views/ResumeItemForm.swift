//
//  ResumeItemForm.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Fields for whatever is selected in the outline. These are the resume's own copies; editing
/// them never touches the Career Profile (FR-034).
struct ResumeItemForm: View {
    let editor: RecordEditor<Resume>
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    @Binding var document: ResumeDocument
    @Binding var selection: ResumeOutlineItem?

    var body: some View {
        Form {
            if editor.error(for: \.title) != nil, selection != .info {
                Section {
                    FieldError(editor.error(for: \.title))
                    Button("Open Resume Info") { selection = .info }
                }
            }
            switch selection {
            case .info:
                infoFields
            case .header:
                headerFields
                summaryField
            case .section(let id):
                if let section = sectionBinding(id) {
                    SectionFields(section: section, selection: $selection) {
                        selection = .header
                        document.sections.removeAll { $0.id == id }
                    }
                }
            case .entry(let id):
                if let position = document.entryPosition(id), let entry = entryBinding(id) {
                    let section = document.sections[position.section]
                    EntryFields(entry: entry, kind: section.kind) {
                        selection = .section(section.id)
                        document.sections[position.section].entries.removeAll { $0.id == id }
                    }
                }
            case nil:
                Text("Select an item in the outline.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var infoFields: some View {
        Group {
            Section {
                TextField("Resume Name", text: editor.binding(\.title), prompt: Text("Required"))
                FieldError(editor.error(for: \.title))
                TextField("Target Position", text: editor.binding(\.targetPosition), prompt: Text("iOS Developer"))
            } header: {
                Text("Resume Info")
            } footer: {
                Text("Only you see these. They don't appear on the resume.")
            }
            Section("Job Description") {
                TextField(
                    "Job Description",
                    text: editor.binding(\.jobDescription),
                    prompt: Text("Paste the job description for this version"),
                    axis: .vertical
                )
                .labelsHidden()
                .lineLimit(6...20)
            }
            if !editor.record.applications.isEmpty {
                Section {
                    ForEach(editor.record.applications.sorted { $0.company < $1.company }) { application in
                        Button {
                            changes.perform {
                                navigation.recordToOpen = application.id
                                navigation.section = .applications
                            }
                        } label: {
                            Label {
                                Text("\(application.position) · \(application.company)")
                            } icon: {
                                OrganizationLogo(name: application.company, size: 18)
                            }
                        }
                        .buttonStyle(.link)
                    }
                } header: {
                    Text("Sent With")
                } footer: {
                    Text("Applications that use this resume. Link one from the application.")
                }
            }
        }
    }

    private var headerFields: some View {
        Section("Header") {
            TextField("Full Name", text: $document.header.fullName)
            TextField("Headline", text: $document.header.headline, prompt: Text("iOS Engineer"))
            TextField("Email", text: $document.header.email, prompt: Text("name@example.com"))
            TextField("Phone", text: $document.header.phone)
            TextField("Location", text: $document.header.location, prompt: Text("City, Country"))
            PairListEditor(
                items: $document.header.links,
                first: \.label,
                second: \.url,
                prompts: (String(localized: "Label"), String(localized: "URL")),
                addTitle: String(localized: "Add Link"),
                makeItem: { ProfileLink(label: "", url: "") }
            )
        }
    }

    private var summaryField: some View {
        Section {
            TextField(
                "Summary",
                text: $document.summary,
                prompt: Text("Two or three sentences about your experience and focus"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(3...12)
        } header: {
            Text("Summary")
        } footer: {
            Text("Appears under your contact details without a heading. Leave it empty if you don't need one.")
        }
    }

    // Bindings by id, not index: a row removed mid-update must not crash a field still reading it.
    private func sectionBinding(_ id: UUID) -> Binding<ResumeSection>? {
        guard let current = document.sections.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { document.sections.first { $0.id == id } ?? current },
            set: { new in
                if let index = document.sections.firstIndex(where: { $0.id == id }) { document.sections[index] = new }
            }
        )
    }

    private func entryBinding(_ id: UUID) -> Binding<ResumeEntry>? {
        guard let position = document.entryPosition(id) else { return nil }
        let current = document.sections[position.section].entries[position.entry]
        return Binding(
            get: { document.entryPosition(id).map { document.sections[$0.section].entries[$0.entry] } ?? current },
            set: { new in
                if let p = document.entryPosition(id) { document.sections[p.section].entries[p.entry] = new }
            }
        )
    }
}

/// A section: its entries to jump to, adding one, and removing the section.
private struct SectionFields: View {
    @Binding var section: ResumeSection
    @Binding var selection: ResumeOutlineItem?
    let onRemove: () -> Void

    var body: some View {
        Section {
            ForEach(section.entries) { entry in
                Button(entry.title.isBlank ? section.kind.newEntryTitle : entry.title) {
                    selection = .entry(entry.id)
                }
                .buttonStyle(.link)
            }
            AddButton(title: section.kind.addTitle) {
                let entry = ResumeEntry()
                section.entries.append(entry)
                selection = .entry(entry.id)
            }
        } header: {
            Text(section.title)
        } footer: {
            Text("Drag sections and entries in the outline to reorder them.")
        }
        Section {
            Picker("Heading", selection: heading) {
                ForEach(section.kind.headingOptions, id: \.self) { Text($0).tag($0) }
            }
        } footer: {
            Text("Standard headings that applicant tracking systems recognize.")
        }
        Section {
            Button("Remove Section", role: .destructive, action: onRemove)
        }
    }

    /// The default heading is stored as nil.
    private var heading: Binding<String> {
        Binding(
            get: { section.title },
            set: { section.heading = $0 == section.kind.heading ? nil : $0 }
        )
    }
}

private struct EntryFields: View {
    @Binding var entry: ResumeEntry
    let kind: ResumeSection.Kind
    let onDelete: () -> Void

    var body: some View {
        Section(kind.heading) {
            TextField(kind.titleLabel, text: $entry.title, prompt: Text(kind.titlePrompt))
            TextField(kind.subtitleLabel, text: $entry.subtitle, prompt: Text(kind.subtitlePrompt))
            if kind == .experience {
                TitlePicker("Employment Type", selection: $entry.employmentType, options: EmploymentType.allCases.map(\.title))
            }
            if kind == .experience || kind == .organizational {
                TitlePicker("Work Arrangement", selection: $entry.workArrangement, options: WorkArrangement.allCases.map(\.title))
            }
        }
        if kind != .skills {
            datesSection
        }
        if kind == .education {
            Section("Academic Details") {
                TextField("GPA or Score", text: optional(\.grade), prompt: Text("3.86/4.00"))
                TextField("Thesis", text: optional(\.thesis), prompt: Text("Title of your thesis"), axis: .vertical)
            }
            Section("Relevant Coursework") {
                StringListEditor(
                    items: Binding(get: { entry.coursework ?? [] }, set: { entry.coursework = $0.isEmpty ? nil : $0 }),
                    prompt: String(localized: "Course name"),
                    addTitle: String(localized: "Add Course")
                )
            }
        }
        if kind != .skills {
            Section("Bullet Points") {
                StringListEditor(
                    items: $entry.bullets,
                    prompt: String(localized: "What you did and the result"),
                    addTitle: String(localized: "Add Bullet Point")
                )
            }
            Section {
                TextField("Proof Link", text: optional(\.proofURL), prompt: Text("https://"))
            } footer: {
                Text("When Layout → Link Proof is on, the title opens this link in the PDF.")
            }
        }
        Section {
            Button("Delete Entry", role: .destructive, action: onDelete)
        }
    }

    /// Month and year pickers. Achievements and certifications have one date; the rest a range.
    @ViewBuilder
    private var datesSection: some View {
        let isSingleDate = kind == .achievements || kind == .certifications
        Section("Dates") {
            YearMonthField(title: isSingleDate ? String(localized: "Date") : String(localized: "Start"), value: date(\.start))
            if !isSingleDate {
                if kind != .projects {
                    Toggle("Present", isOn: Binding(
                        get: { entry.isCurrent == true },
                        set: { value in setDates { $0.isCurrent = value; if value { $0.end = nil } } }
                    ))
                }
                if entry.isCurrent != true {
                    YearMonthField(title: String(localized: "End"), value: date(\.end))
                }
            }
            // Resumes made before the pickers, or typed by hand, keep their text until a date is picked.
            if !entry.hasDateValues, !entry.dates.isBlank {
                TextField("Dates as Typed", text: $entry.dates)
            }
        }
    }

    private func date(_ field: WritableKeyPath<ResumeEntry, YearMonth?>) -> Binding<YearMonth?> {
        Binding(get: { entry[keyPath: field] }, set: { value in setDates { $0[keyPath: field] = value } })
    }

    /// Changes the date values and keeps the text in step, for history and suggestions.
    private func setDates(_ change: (inout ResumeEntry) -> Void) {
        var new = entry
        change(&new)
        new.dates = new.hasDateValues
            ? YearMonth.rangeText(start: new.start, end: new.end, isCurrent: new.isCurrent == true)
            : ""
        entry = new
    }

    /// Empty text is stored as nil.
    private func optional(_ field: WritableKeyPath<ResumeEntry, String?>) -> Binding<String> {
        Binding(get: { entry[keyPath: field] ?? "" }, set: { entry[keyPath: field] = $0.isBlank ? nil : $0 })
    }
}

/// A dropdown that stores the chosen title as text; a value typed before the dropdown existed stays listed.
private struct TitlePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: String?
    let options: [String]

    init(_ title: LocalizedStringKey, selection: Binding<String?>, options: [String]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not Set").tag(String?.none)
            Divider()
            ForEach(allOptions, id: \.self) { Text($0).tag(String?.some($0)) }
        }
    }

    private var allOptions: [String] {
        guard let selection, !selection.isBlank, !options.contains(selection) else { return options }
        return options + [selection]
    }
}

/// Labels and titles that say what each section actually holds.
extension ResumeSection.Kind {
    var systemImage: String {
        switch self {
        case .experience: "briefcase"
        case .organizational: "person.3"
        case .education: "graduationcap"
        case .projects: "hammer"
        case .achievements: "trophy"
        case .certifications: "checkmark.seal"
        case .skills: "star"
        }
    }

    var titleLabel: String {
        switch self {
        case .experience, .organizational: String(localized: "Role")
        case .education: String(localized: "Degree")
        case .projects: String(localized: "Project")
        case .achievements: String(localized: "Award")
        case .certifications: String(localized: "Certificate")
        case .skills: String(localized: "Category")
        }
    }

    var titlePrompt: String {
        switch self {
        case .experience: String(localized: "iOS Engineer")
        case .organizational: String(localized: "Event Lead")
        case .education: String(localized: "Bachelor of Computer Science")
        case .projects: String(localized: "Project name")
        case .achievements: String(localized: "Best Pitching Team")
        case .certifications: String(localized: "AWS Cloud Practitioner")
        case .skills: String(localized: "Languages (optional)")
        }
    }

    var subtitleLabel: String {
        switch self {
        case .experience: String(localized: "Company")
        case .organizational: String(localized: "Organization")
        case .education: String(localized: "School")
        case .projects: String(localized: "Your Role")
        case .achievements: String(localized: "Given By")
        case .certifications: String(localized: "Issuer")
        case .skills: String(localized: "Skills")
        }
    }

    var subtitlePrompt: String {
        switch self {
        case .experience, .organizational: String(localized: "Acme · Jakarta")
        case .education: String(localized: "Universitas Indonesia · Depok")
        case .projects: String(localized: "Lead Developer · link")
        case .achievements: String(localized: "Organizer")
        case .certifications: String(localized: "Amazon Web Services")
        case .skills: String(localized: "Swift, Kotlin, Python")
        }
    }

    var addTitle: String {
        switch self {
        case .experience: String(localized: "Add Experience")
        case .organizational: String(localized: "Add Organization")
        case .education: String(localized: "Add Education")
        case .projects: String(localized: "Add Project")
        case .achievements: String(localized: "Add Achievement")
        case .certifications: String(localized: "Add Certification")
        case .skills: String(localized: "Add Skill Line")
        }
    }

    var newEntryTitle: String {
        switch self {
        case .experience: String(localized: "New Experience")
        case .organizational: String(localized: "New Organization")
        case .education: String(localized: "New Education")
        case .projects: String(localized: "New Project")
        case .achievements: String(localized: "New Achievement")
        case .certifications: String(localized: "New Certification")
        case .skills: String(localized: "New Skill Line")
        }
    }
}

#Preview {
    @Previewable @State var selection: ResumeOutlineItem? = .header
    let editor = RecordEditor<Resume>.preview()
    ResumeItemForm(editor: editor, document: editor.binding(\.document), selection: $selection)
        .frame(width: 420, height: 600)
        .previewEnvironment()
}
