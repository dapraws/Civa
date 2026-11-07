//
//  ClaudeReviewViews.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Claude's suggested wording for one resume, applied or dismissed one at a time (FR-073).
/// Applying saves a "Before Claude's Changes" version first (FR-043); like other edits, the
/// change stays unsaved until the resume is saved.
struct ClaudeResumeProposalsSheet: View {
    let editor: RecordEditor<Resume>
    let proposals: [ClaudeProposal]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var decided: Set<UUID> = []

    var body: some View {
        let open = proposals.filter { !decided.contains($0.id) }
        VStack(spacing: 0) {
            if open.isEmpty {
                ContentUnavailableView("No Suggestions Left", systemImage: "checkmark.circle", description: Text("You've gone through Claude's suggestions for this resume."))
            } else {
                Form {
                    ForEach(open) { proposal in
                        if let edit = proposal.decode(ClaudeProposal.ResumeEdit.self) {
                            Section {
                                if !proposal.note.isBlank {
                                    Label(proposal.note, systemImage: "sparkles").foregroundStyle(.secondary)
                                }
                                if let summary = edit.summary {
                                    ChangeRow(label: String(localized: "Summary"), old: editor.record.document.summary, new: summary)
                                }
                                ForEach(edit.entries, id: \.entryID) { change in
                                    entryRows(change)
                                }
                                HStack {
                                    Spacer()
                                    Button("Dismiss") { decide(proposal, .dismissed) }
                                    Button("Apply") {
                                        editor.update { resume in
                                            resume.recordSnapshot(.beforeClaude, in: context)
                                            var document = resume.document
                                            ClaudeDecisions.apply(edit, to: &document)
                                            resume.document = document
                                        }
                                        decide(proposal, .applied)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } header: {
                                Text("Suggested \(proposal.createdAt.formatted(.relative(presentation: .named)))")
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
            Divider()
            HStack {
                Text("Applied changes stay unsaved until you save the resume. History keeps the version before.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 640, height: 560)
    }

    @ViewBuilder
    private func entryRows(_ change: ClaudeProposal.ResumeEdit.Entry) -> some View {
        let document = editor.record.document
        if let position = document.entryPosition(change.entryID) {
            let entry = document.sections[position.section].entries[position.entry]
            if let title = change.title, title != entry.title {
                ChangeRow(label: String(localized: "Title"), old: entry.title, new: title)
            }
            if let subtitle = change.subtitle, subtitle != entry.subtitle {
                ChangeRow(label: entry.title, old: entry.subtitle, new: subtitle)
            }
            if let bullets = change.bullets, bullets != entry.bullets {
                ChangeRow(label: entry.title, old: entry.bullets.map { "• \($0)" }.joined(separator: "\n"), new: bullets.map { "• \($0)" }.joined(separator: "\n"))
            }
        }
    }

    private func decide(_ proposal: ClaudeProposal, _ status: ClaudeProposal.Status) {
        decided.insert(proposal.id)
        ClaudeDecisions.record(proposal.id, status, container: context.container)
    }
}

/// Before and after, one field.
struct ChangeRow: View {
    let label: String
    let old: String
    let new: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            if !old.isBlank {
                Text(old).strikethrough().foregroundStyle(.secondary).textSelection(.enabled)
            }
            Text(new).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

/// Above a resume Claude drafted: keep it, or discard it (FR-073).
struct ClaudeDraftBanner: View {
    let editor: RecordEditor<Resume>

    @Environment(\.modelContext) private var context
    @Environment(\.closeRecordEditor) private var close
    @Query(filter: #Predicate<ClaudeProposal> { $0.kindRaw == "resumeDraft" }) private var drafts: [ClaudeProposal]
    @State private var isConfirmingDiscard = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(.tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude drafted this resume").font(.headline)
                Text(proposal?.note.isBlank == false ? proposal!.note : String(localized: "It's built from your confirmed Career Profile. Keep it to make it a regular resume, or discard it."))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
            Button("Discard…") { isConfirmingDiscard = true }
            Button("Keep Draft", action: keep).buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.tint.opacity(0.08))
        .confirmationDialog("Discard this draft?", isPresented: $isConfirmingDiscard) {
            Button("Discard Draft", role: .destructive, action: discard)
        } message: {
            Text("The draft is deleted. Your Career Profile and other resumes don't change.")
        }
    }

    private var proposal: ClaudeProposal? {
        drafts.first { $0.targetID == editor.record.id }
    }

    private func keep() {
        editor.update { resume in
            resume.isClaudeDraft = false
            resume.recordSnapshot(.createdByClaude, in: context)
        }
        guard editor.save() else { return }
        if let proposal { ClaudeDecisions.record(proposal.id, .applied, container: context.container) }
    }

    private func discard() {
        let id = proposal?.id
        if editor.delete() {
            if let id { ClaudeDecisions.record(id, .dismissed, container: context.container) }
            close()
        }
    }
}

/// Claude's pending suggestions for one profile record, at the top of its editor (FR-073).
struct ClaudeRecordProposalsSection<Model: ClaudeEditable>: View {
    let editor: RecordEditor<Model>

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ClaudeProposal> { $0.kindRaw == "recordEdit" && $0.statusRaw == "pending" }) private var proposals: [ClaudeProposal]

    var body: some View {
        ForEach(proposals.filter { $0.targetID == editor.record.id }) { proposal in
            if let edit = proposal.decode(ClaudeProposal.RecordEdit.self) {
                Section {
                    if !proposal.note.isBlank {
                        Text(proposal.note).foregroundStyle(.secondary)
                    }
                    ChangeRow(
                        label: title(edit.field),
                        old: lines(editor.record.current(edit.field), edit.field),
                        new: lines(edit.lines ?? [edit.text ?? ""], edit.field)
                    )
                    HStack {
                        Spacer()
                        Button("Dismiss") { ClaudeDecisions.record(proposal.id, .dismissed, container: context.container) }
                        Button("Apply") {
                            editor.update { $0.apply(edit) }
                            ClaudeDecisions.record(proposal.id, .applied, container: context.container)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Label("Suggested by Claude", systemImage: "sparkles")
                } footer: {
                    Text("Applying changes this record; save it to keep the change.")
                }
            }
        }
    }

    private func title(_ field: ClaudeProposal.RecordEdit.Field) -> String {
        switch field {
        case .impacts: String(localized: "Impact")
        case .details: String(localized: "Description")
        case .summary: String(localized: "Summary")
        case .headline: String(localized: "Headline")
        }
    }

    private func lines(_ values: [String], _ field: ClaudeProposal.RecordEdit.Field) -> String {
        field == .impacts ? values.filter { !$0.isBlank }.map { "• \($0)" }.joined(separator: "\n") : values.joined()
    }
}

/// On the Dashboard: requests waiting for Claude and suggestions waiting for the user (FR-072, FR-073).
struct ClaudeInboxCard: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \ClaudeRequest.createdAt, order: .reverse) private var requests: [ClaudeRequest]
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }, sort: \ClaudeProposal.createdAt, order: .reverse)
    private var proposals: [ClaudeProposal]
    @State private var importRequest: ImportRequest?

    var body: some View {
        let waiting = requests.filter { $0.status == .pending || $0.status == .failed }
        if !waiting.isEmpty || !proposals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Claude", systemImage: "sparkles").font(.headline)
                ForEach(proposals) { proposal in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ClaudeDecisions.describe(proposal))
                            if !proposal.note.isBlank {
                                Text(proposal.note).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        if proposal.kind == .profileImport {
                            Button("Dismiss") { ClaudeDecisions.record(proposal.id, .dismissed, container: context.container) }
                        }
                        Button("Review") { open(proposal) }.buttonStyle(.borderedProminent)
                    }
                }
                ForEach(waiting) { request in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.title)
                            Text(request.status == .failed
                                 ? String(localized: "Claude couldn't finish: \(request.note)")
                                 : String(localized: "Waiting. In Claude Desktop, ask “Run my Civa requests”."))
                                .font(.callout)
                                .foregroundStyle(request.status == .failed ? .orange : .secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Cancel") { set(request, .cancelled) }
                        if request.status == .failed {
                            Button("Ask Again") {
                                set(request, .pending)
                                ClaudeAsk.openClaude()
                            }
                        } else {
                            Button("Open Claude") { ClaudeAsk.openClaude() }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.separator) }
            .sheet(item: $importRequest) { ImportReviewSheet(request: $0) }
        }
    }

    private func set(_ request: ClaudeRequest, _ status: ClaudeRequest.Status) {
        let id = request.id
        let side = ModelContext(context.container)
        guard let request = try? side.fetch(FetchDescriptor<ClaudeRequest>(predicate: #Predicate { $0.id == id })).first else { return }
        request.status = status
        if status == .pending { request.note = "" }
        try? side.save()
    }

    private func open(_ proposal: ClaudeProposal) {
        switch proposal.kind {
        case .profileImport:
            importRequest = .claude(proposal)
        case .resumeEdit, .resumeDraft:
            navigation.recordToOpen = proposal.targetID
            navigation.section = .resumes
        case .recordEdit:
            navigation.profileCategory = switch proposal.category {
            case .personal: .personal
            case .projects: .projects
            default: profileCategory(forExperience: proposal.targetID)
            }
            navigation.recordToOpen = proposal.targetID
            navigation.section = .careerProfile
        }
    }

    private func profileCategory(forExperience id: UUID?) -> ProfileCategory {
        guard let id, let experience = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first else { return .professional }
        return experience.kind == .professional ? .professional : .organizational
    }
}

#Preview("Inbox") {
    ClaudeInboxCard().padding().frame(width: 600).previewEnvironment()
}
