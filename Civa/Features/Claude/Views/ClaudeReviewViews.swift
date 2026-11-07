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
    /// The version picked for each change, per suggestion.
    @State private var picks: [UUID: [ClaudeProposal.ResumeEdit.Change: Int]] = [:]

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
                                    Label(proposal.note, systemImage: "sparkles").foregroundStyle(.claude)
                                }
                                let versions = edit.summaryVersions
                                if versions.count > 1 {
                                    VersionChoices(
                                        label: String(localized: "Summary"), current: editor.record.document.summary,
                                        versions: versions.map { ($0.label, $0.text ?? "") },
                                        selection: pick(proposal, .summary)
                                    )
                                } else if let summary = versions.first?.text {
                                    ChangeRow(label: String(localized: "Summary"), old: editor.record.document.summary, new: summary)
                                }
                                ForEach(edit.entries, id: \.entryID) { change in
                                    entryRows(change, proposal: proposal)
                                }
                                let chosen = edit.resolved(picks[proposal.id] ?? [:])
                                HStack {
                                    Spacer()
                                    Button(edit.hasOptions ? "Keep Mine" : "Dismiss") { decide(proposal, .dismissed) }
                                    Button(edit.hasOptions ? "Use Selected" : "Apply") {
                                        editor.update { resume in
                                            resume.recordSnapshot(.beforeClaude, in: context)
                                            var document = resume.document
                                            ClaudeDecisions.apply(chosen, to: &document)
                                            resume.document = document
                                        }
                                        decide(proposal, .applied, choice: choiceLabels(edit, proposal))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.claude)
                                    .disabled(chosen.summary == nil && chosen.entries.isEmpty)
                                    .help(chosen.summary == nil && chosen.entries.isEmpty ? "Pick a version first" : "")
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
        // Short when there's only a message, so it doesn't sit in a mostly empty sheet.
        .frame(width: 640, height: open.isEmpty ? 280 : 560)
    }

    private func pick(_ proposal: ClaudeProposal, _ change: ClaudeProposal.ResumeEdit.Change) -> Binding<Int?> {
        Binding(
            get: { picks[proposal.id]?[change] },
            set: { picks[proposal.id, default: [:]][change] = $0 }
        )
    }

    /// "Summary: Concise; iOS Engineer: With Numbers", for the activity log.
    private func choiceLabels(_ edit: ClaudeProposal.ResumeEdit, _ proposal: ClaudeProposal) -> String? {
        guard edit.hasOptions else { return nil }
        let picked = picks[proposal.id] ?? [:]
        var labels: [String] = []
        if let index = picked[.summary], edit.summaryVersions.indices.contains(index) {
            labels.append(String(localized: "Summary: \(edit.summaryVersions[index].label)"))
        }
        for entry in edit.entries {
            if let index = picked[.entry(entry.entryID)], entry.versions.indices.contains(index),
               let position = editor.record.document.entryPosition(entry.entryID) {
                let title = editor.record.document.sections[position.section].entries[position.entry].title
                labels.append("\(title): \(entry.versions[index].label)")
            }
        }
        return labels.isEmpty ? nil : labels.joined(separator: "; ")
    }

    @ViewBuilder
    private func entryRows(_ change: ClaudeProposal.ResumeEdit.Entry, proposal: ClaudeProposal) -> some View {
        let document = editor.record.document
        if let position = document.entryPosition(change.entryID) {
            let entry = document.sections[position.section].entries[position.entry]
            if change.versions.count > 1 {
                VersionChoices(
                    label: entry.title, current: Self.describe(entry.title, entry.subtitle, entry.bullets),
                    versions: change.versions.map { version in
                        (version.label, Self.describe(version.title ?? entry.title, version.subtitle ?? entry.subtitle, version.lines ?? entry.bullets))
                    },
                    selection: pick(proposal, .entry(change.entryID))
                )
            } else if let title = change.title, title != entry.title {
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

    /// An entry as one block of text: title, subtitle, then bullets.
    private static func describe(_ title: String, _ subtitle: String, _ bullets: [String]) -> String {
        ([title, subtitle].filter { !$0.isBlank } + bullets.map { "• \($0)" }).joined(separator: "\n")
    }

    private func decide(_ proposal: ClaudeProposal, _ status: ClaudeProposal.Status, choice: String? = nil) {
        decided.insert(proposal.id)
        ClaudeDecisions.record(proposal.id, status, container: context.container, choice: choice)
    }
}

/// Yours, then Claude's 2–3 labeled versions to pick from. Nothing is picked at first.
struct VersionChoices: View {
    let label: String
    let current: String
    let versions: [(label: String, text: String)]
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            if !current.isBlank {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yours").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(current).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            ForEach(versions.indices, id: \.self) { index in
                Button {
                    selection = selection == index ? nil : index
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: selection == index ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selection == index ? .claude : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(versions[index].label).font(.callout.weight(.semibold)).foregroundStyle(.claude)
                            Text(versions[index].text).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .contentShape(.rect)
                    .background(selection == index ? Color.claude.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
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
            Image(systemName: "sparkles").foregroundStyle(.claude).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude drafted this resume").font(.headline)
                Text(proposal?.note.isBlank == false ? proposal!.note : String(localized: "It's built from your confirmed Career Profile. Keep it to make it a regular resume, or discard it."))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
            Button("Discard…") { isConfirmingDiscard = true }
            Button("Keep Draft", action: keep).buttonStyle(.borderedProminent).tint(.claude)
        }
        .padding(12)
        .background(.claude.opacity(0.12))
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
    @State private var picks: [UUID: Int] = [:]

    var body: some View {
        ForEach(proposals.filter { $0.targetID == editor.record.id }) { proposal in
            if let edit = proposal.decode(ClaudeProposal.RecordEdit.self) {
                Section {
                    if !proposal.note.isBlank {
                        Text(proposal.note).foregroundStyle(.secondary)
                    }
                    let versions = edit.versions
                    if versions.count > 1 {
                        VersionChoices(
                            label: title(edit.field),
                            current: lines(editor.record.current(edit.field), edit.field),
                            versions: versions.map { ($0.label, lines($0.lines ?? [$0.text ?? ""], edit.field)) },
                            selection: Binding(get: { picks[proposal.id] }, set: { picks[proposal.id] = $0 })
                        )
                    } else {
                        ChangeRow(
                            label: title(edit.field),
                            old: lines(editor.record.current(edit.field), edit.field),
                            new: lines(edit.lines ?? [edit.text ?? ""], edit.field)
                        )
                    }
                    let pick = versions.count > 1 ? picks[proposal.id] : 0
                    HStack {
                        Spacer()
                        Button(versions.count > 1 ? "Keep Mine" : "Dismiss") { ClaudeDecisions.record(proposal.id, .dismissed, container: context.container) }
                        Button(versions.count > 1 ? "Use Selected" : "Apply") {
                            guard let pick else { return }
                            editor.update { $0.apply(edit.resolved(pick)) }
                            ClaudeDecisions.record(
                                proposal.id, .applied, container: context.container,
                                choice: versions.count > 1 ? versions[pick].label : nil
                            )
                        }
                        .disabled(pick == nil)
                        .buttonStyle(.borderedProminent)
                        .tint(.claude)
                    }
                } header: {
                    Label("Suggested by Claude", systemImage: "sparkles").foregroundStyle(.claude)
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
    @Query(sort: \ClaudeRequest.createdAt, order: .reverse) private var requests: [ClaudeRequest]
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }, sort: \ClaudeProposal.createdAt, order: .reverse)
    private var proposals: [ClaudeProposal]

    var body: some View {
        let waiting = requests.filter { $0.status == .pending || $0.status == .failed }
        if !waiting.isEmpty || !proposals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Claude", systemImage: "sparkles").font(.headline).foregroundStyle(.claude)
                ForEach(proposals) { ClaudeProposalRow(proposal: $0) }
                ForEach(waiting) { ClaudeRequestRow(request: $0) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.claude.opacity(0.5)) }
        }
    }
}

#Preview("Inbox") {
    ClaudeInboxCard().padding().frame(width: 600).previewEnvironment()
}
