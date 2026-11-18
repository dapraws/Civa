//
//  AIActivityView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Everything Claude did in one place: what you asked it, what it suggested, and the full log
/// of what it read (FR-072, FR-074, FR-075).
struct AIActivityView: View {
    enum Tab: Hashable, CaseIterable, Identifiable {
        case suggestions, requests, log

        var id: Self { self }

        var title: String {
            switch self {
            case .suggestions: String(localized: "Suggestions")
            case .requests: String(localized: "Requests")
            case .log: String(localized: "Log")
            }
        }
    }

    @Environment(AppNavigation.self) private var navigation
    @State private var tab = Tab.suggestions
    @State private var kind: ClaudeActivity.Kind?
    @State private var category: ClaudeCategory?
    @Query(sort: \ClaudeRequest.createdAt, order: .reverse) private var requests: [ClaudeRequest]
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }, sort: \ClaudeProposal.createdAt, order: .reverse)
    private var proposals: [ClaudeProposal]
    @Query(sort: \ClaudeActivity.date, order: .reverse) private var activity: [ClaudeActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(String(localized: "AI Activity"))
                .padding(.horizontal, Space.xl)
                .padding(.top, 20)
            SegmentedTabs(Tab.allCases, selection: $tab, title: \.title) { tab in
                switch tab {
                case .suggestions: proposals.isEmpty ? nil : proposals.count
                case .requests: requests.isEmpty ? nil : requests.count
                case .log: nil
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.m)
            Rectangle().fill(Color.hairline).frame(height: 1)
            // Empty tabs show one message on the page instead of a card in a form.
            if tab == .suggestions, proposals.isEmpty {
                empty("No suggestions to review", "What Claude suggests appears here and on the page it's about. Nothing changes until you apply it.")
            } else if tab == .requests, requests.isEmpty {
                VStack(alignment: .leading, spacing: Space.l) {
                    EmptyStateView(
                        symbol: "sparkles",
                        title: "Nothing asked yet",
                        message: "Use the orange Claude buttons on resumes, experience, projects, and applications.",
                        symbolColor: .claude
                    )
                    ClaudeHowItWorks().frame(maxWidth: 420, alignment: .leading)
                }
                .padding(.horizontal, Space.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if tab == .log, activity.isEmpty {
                empty("No activity yet", "Everything Claude reads or suggests is logged here.")
            } else {
                list
            }
        }
        .background(Color.canvas)
        .onChange(of: navigation.aiActivityTab, initial: true) { _, next in
            guard let next else { return }
            tab = next
            navigation.aiActivityTab = nil
        }
    }

    private var list: some View {
        Form {
            switch tab {
            case .suggestions:
                Section {
                    ForEach(proposals) { ClaudeProposalRow(proposal: $0) }
                }
            case .requests:
                Section {
                    ForEach(requests) { ClaudeRequestRow(request: $0, showsAll: true) }
                }
                Section(civa: "How It Works") {
                    ClaudeHowItWorks().padding(.vertical, 4)
                }
            case .log:
                let entries = activity.filter { (kind == nil || $0.kind == kind) && (category == nil || $0.category == category) }
                Section {
                    if entries.isEmpty {
                        Text("No activity matches.").foregroundStyle(.secondary)
                    }
                    ForEach(entries) { ClaudeActivityRow(entry: $0, showsDate: true) }
                } header: {
                    HStack {
                        Picker("Kind", selection: $kind) {
                            Text("All Kinds").tag(ClaudeActivity.Kind?.none)
                            ForEach(ClaudeActivity.Kind.allCases, id: \.self) { Text($0.title).tag(ClaudeActivity.Kind?.some($0)) }
                        }
                        Picker("Category", selection: $category) {
                            Text("All Categories").tag(ClaudeCategory?.none)
                            ForEach(ClaudeCategory.allCases) { Text($0.title).tag(ClaudeCategory?.some($0)) }
                        }
                    }
                    .fixedSize()
                }
            }
        }
        .civaForm()
    }

    /// DESIGN.md §8.8: the one empty state with a colored symbol, because this page is Claude's.
    private func empty(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        EmptyStateView(symbol: "sparkles", title: title, message: message, symbolColor: .claude)
            .padding(.horizontal, Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A suggestion from Claude with a way to review it where it applies.
struct ClaudeProposalRow: View {
    let proposal: ClaudeProposal

    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation
    @State private var importRequest: ImportRequest?

    var body: some View {
        HStack {
            Image(systemName: "sparkles").foregroundStyle(.claude).accessibilityHidden(true)
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
            Button("Review", action: open).civaButton(.textLink, color: .claudeText)
        }
        .sheet(item: $importRequest) { ImportReviewSheet(request: $0) }
    }

    private func open() {
        switch proposal.kind {
        case .profileImport:
            importRequest = .claude(proposal)
        case .resumeEdit, .resumeDraft:
            navigation.recordToOpen = proposal.targetID
            navigation.section = .resumes
        case .recordEdit:
            navigation.otherKind = nil
            navigation.profileCategory = switch proposal.category {
            case .personal: .personal
            case .projects: .projects
            case .education: .education
            case .recognition, .skills: .other
            default: experienceCategory(proposal.targetID)
            }
            if proposal.category == .skills { navigation.otherKind = "skills" }
            if proposal.category == .recognition { navigation.otherKind = isCertification(proposal.targetID) ? "certifications" : "achievements" }
            navigation.recordToOpen = proposal.category == .personal ? nil : proposal.targetID
            navigation.section = .careerProfile
        }
    }

    private func isCertification(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return (try? context.fetch(FetchDescriptor<Certification>(predicate: #Predicate { $0.id == id })).first) != nil
    }

    private func experienceCategory(_ id: UUID?) -> ProfileCategory {
        guard let id, let experience = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first else { return .professional }
        return experience.kind == .professional ? .professional : .organizational
    }
}

/// A request for Claude: waiting, finished, failed, or cancelled.
struct ClaudeRequestRow: View {
    let request: ClaudeRequest
    /// Finished and cancelled requests too, with their status, as in AI Activity.
    var showsAll = false

    @Environment(\.modelContext) private var context
    @State private var showsHelp = false

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(request.status == .failed ? .red : .claude).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                Text(status)
                    .font(.callout)
                    .foregroundStyle(request.status == .failed ? .red : .secondary)
                    .lineLimit(2)
            }
            Spacer()
            if showsAll {
                Text(request.createdAt.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.secondary)
            }
            switch request.status {
            case .pending:
                Button("How do I start this?", systemImage: "questionmark.circle") { showsHelp = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showsHelp, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 14) {
                            ClaudeHowItWorks()
                            Button("Open Claude") { ClaudeAsk.openClaude() }
                                .civaButton(.claude)
                        }
                        .padding()
                        .frame(width: 360)
                    }
                Button("Cancel") { set(.cancelled) }
                Button("Open Claude") { ClaudeAsk.openClaude() }
                    .help("Copies “\(ClaudeAsk.prompt)” and opens Claude Desktop")
            case .failed:
                Button("Cancel") { set(.cancelled) }
                Button("Ask Again") {
                    set(.pending)
                    ClaudeAsk.openClaude()
                }
            case .answered, .cancelled:
                EmptyView()
            }
        }
    }

    private var icon: String {
        switch request.status {
        case .pending: "hourglass"
        case .answered: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        }
    }

    private var status: String {
        switch request.status {
        case .pending: String(localized: "Waiting. In Claude Desktop, ask “\(ClaudeAsk.prompt)”")
        case .answered: String(localized: "Claude answered. Its suggestion is under Suggestions.")
        case .failed: String(localized: "Claude couldn't finish: \(request.note)")
        case .cancelled: String(localized: "Cancelled")
        }
    }

    /// Through its own context, so an open editor's unsaved edits stay unsaved.
    private func set(_ status: ClaudeRequest.Status) {
        let id = request.id
        let side = ModelContext(context.container)
        guard let request = try? side.fetch(FetchDescriptor<ClaudeRequest>(predicate: #Predicate { $0.id == id })).first else { return }
        request.status = status
        if status == .pending { request.note = "" }
        try? side.save()
    }
}

/// One audit log entry (FR-074).
struct ClaudeActivityRow: View {
    let entry: ClaudeActivity
    var showsDate = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: entry.kind.systemImage)
                .foregroundStyle(entry.kind.color)
                .accessibilityLabel(entry.kind.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                if !entry.detail.isEmpty {
                    Text(entry.detail.replacingOccurrences(of: "\n", with: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(showsDate ? 4 : 1)
                        .textSelection(.enabled)
                }
            }
            Spacer()
            Text(showsDate ? entry.date.formatted(date: .abbreviated, time: .shortened) : entry.date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension ClaudeActivity.Kind {
    var title: String {
        switch self {
        case .read: String(localized: "Read")
        case .denied: String(localized: "Refused")
        case .suggested: String(localized: "Suggested")
        case .approved: String(localized: "Applied")
        case .rejected: String(localized: "Dismissed")
        }
    }

    var systemImage: String {
        switch self {
        case .read: "eye"
        case .denied: "hand.raised"
        case .suggested: "sparkles"
        case .approved: "checkmark.circle"
        case .rejected: "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .read, .rejected: .secondary
        case .denied: .red
        case .suggested: .claude
        case .approved: .green
        }
    }
}

#Preview {
    NavigationStack {
        AIActivityView()
    }
    .frame(width: 800, height: 560)
    .previewEnvironment()
}
