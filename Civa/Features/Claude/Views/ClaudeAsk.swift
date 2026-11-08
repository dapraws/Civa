//
//  ClaudeAsk.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import SwiftData
import SwiftUI
import TipKit

/// Queues a request for Claude (FR-072) and says so with a notification that opens AI Activity →
/// Requests. Claude Desktop opens only from there: MCP can't start Claude from Civa, so the user
/// sends one short prompt, which "Open Claude" copies to the clipboard.
enum ClaudeAsk {
    static let prompt = "Run my pending Civa requests."

    struct Ask: Equatable {
        let kind: ClaudeRequest.Kind
        /// What Claude needs permission to suggest changes to.
        let category: ClaudeCategory
        let targetID: UUID
        let targetTitle: String
        var applicationID: UUID?
        /// Tailoring: Claude works on a new copy for the job, so the Master or a resume already
        /// sent stays as it is.
        var makesCopy = false
    }

    enum Outcome: Identifiable {
        case notConnected
        case notAllowed(Ask)
        /// The request's title, and the copy Claude will work on when the request made one.
        case queued(title: String, copy: Copy?)
        case failed(String)

        struct Copy {
            let id: UUID
            let title: String
        }

        var id: String {
            switch self {
            case .notConnected: "notConnected"
            case .notAllowed: "notAllowed"
            case .queued: "queued"
            case .failed: "failed"
            }
        }
    }

    /// Queues the request through its own context, so an open editor's unsaved edits stay unsaved.
    static func send(
        _ ask: Ask, container: ModelContainer, permissions: ClaudePermissions = .shared,
        connected: Bool = ClaudeBridge.shared.isEnabled
    ) -> Outcome {
        if ask.makesCopy { return tailorCopy(ask, container: container, permissions: permissions, connected: connected) }
        guard connected else { return .notConnected }
        guard permissions.canSuggest(ask.category) else { return .notAllowed(ask) }
        let context = ModelContext(container)
        let request = ClaudeRequest(kind: ask.kind, targetID: ask.targetID, targetTitle: ask.targetTitle, applicationID: ask.applicationID)
        context.insert(request)
        do {
            try context.save()
        } catch {
            return .failed(error.localizedDescription)
        }
        return .queued(title: request.title, copy: nil)
    }

    /// Makes "<Company> Application" from the target resume, then queues the request on it.
    /// The copy is linked to the application only when the application has no resume yet.
    static func tailorCopy(
        _ ask: Ask, container: ModelContainer, permissions: ClaudePermissions = .shared,
        connected: Bool = ClaudeBridge.shared.isEnabled
    ) -> Outcome {
        guard connected else { return .notConnected }
        guard permissions.canSuggest(ask.category) else { return .notAllowed(ask) }
        let context = ModelContext(container)
        let resumeID = ask.targetID
        guard let resume = try? context.fetch(FetchDescriptor<Resume>(predicate: #Predicate { $0.id == resumeID })).first
        else { return .failed(String(localized: "The resume was deleted.")) }
        let application = ask.applicationID.flatMap { applicationID in
            try? context.fetch(FetchDescriptor<JobApplication>(predicate: #Predicate { $0.id == applicationID })).first
        }
        let copy = resume.tailoredCopy(
            title: application.map { String(localized: "\($0.company) Application") } ?? resume.title,
            targetPosition: application?.position ?? resume.targetPosition,
            jobDescription: application?.jobDescription ?? resume.jobDescription
        )
        context.insert(copy)
        copy.recordSnapshot(.created, in: context)
        if let application, application.resume == nil { application.resume = copy }
        let request = ClaudeRequest(kind: ask.kind, targetID: copy.id, targetTitle: copy.displayTitle, applicationID: ask.applicationID)
        context.insert(request)
        do {
            try context.save()
        } catch {
            return .failed(error.localizedDescription)
        }
        return .queued(title: request.title, copy: .init(id: copy.id, title: copy.displayTitle))
    }

    /// Why an Ask Claude button can't be used yet, in the order the user would fix it.
    static func unavailable(isNew: Bool, isDirty: Bool, needsReview: Bool = false, missing: String? = nil) -> String? {
        if isNew { return String(localized: "Save this first, then ask Claude.") }
        if needsReview { return String(localized: "Confirm this record first. Claude only sees confirmed records.") }
        if let missing { return missing }
        if isDirty { return String(localized: "Save your changes first, then ask Claude.") }
        return nil
    }

    /// Copies the prompt and opens Claude Desktop.
    @MainActor
    static func openClaude() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        ClaudeDesktopConfig.openClaude()
    }
}

/// The alerts that follow an Ask Claude button: not set up, not allowed, or a new copy made.
/// A queued request also posts a notice (`ClaudeRequestNotice`); plain requests get no alert.
struct ClaudeAskAlerts: ViewModifier {
    @Binding var outcome: ClaudeAsk.Outcome?
    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation

    /// The alert's item: everything but a plain queued request, which only gets the notice.
    private var alerted: Binding<ClaudeAsk.Outcome?> {
        Binding {
            if case .queued(_, nil) = outcome { return nil }
            return outcome
        } set: { outcome = $0 }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: outcome?.id) {
                guard case .queued(let title, let copy) = outcome else { return }
                ClaudeRequestNotice.shared.post(title)
                if copy == nil { outcome = nil }
            }
            .alert(item: alerted) { outcome in
            switch outcome {
            case .notConnected:
                Alert(
                    title: Text("Claude Desktop Isn't Connected"),
                    message: Text("Set up Claude Desktop in Settings first. Civa works fully without it."),
                    primaryButton: .default(Text("Open Settings")) { navigation.section = .settings },
                    secondaryButton: .cancel()
                )
            case .notAllowed(let ask):
                Alert(
                    title: Text("Allow Claude to Suggest Changes to \(ask.category.title)?"),
                    message: Text("Claude needs to read \(ask.category.title) and suggest changes. Nothing changes until you apply a suggestion. You can turn this off in Settings."),
                    primaryButton: .default(Text("Allow and Ask")) {
                        ClaudePermissions.shared.read.insert(ask.category)
                        ClaudePermissions.shared.suggest.insert(ask.category)
                        // Shown after this alert closes.
                        DispatchQueue.main.async { self.outcome = ClaudeAsk.send(ask, container: context.container) }
                    },
                    secondaryButton: .cancel()
                )
            case .queued(_, let copy?):
                Alert(
                    title: Text("Copy Made for Claude"),
                    message: Text("Claude will tailor “\(copy.title)”, a new copy, so the original stays as it is. Start the request from AI Activity → Requests."),
                    primaryButton: .default(Text("Open Copy")) { navigation.recordToOpen = copy.id },
                    secondaryButton: .cancel(Text("Not Now"))
                )
            case .failed(let reason):
                Alert(title: Text("Civa Couldn't Send the Request"), message: Text(reason))
            case .queued(_, nil):
                // Never shown: `alerted` leaves plain requests to the notice.
                Alert(title: Text("Request Queued"))
            }
        }
    }
}

extension View {
    func claudeAskAlerts(_ outcome: Binding<ClaudeAsk.Outcome?>) -> some View {
        modifier(ClaudeAskAlerts(outcome: outcome))
    }
}

/// An orange button that queues one request. It stays visible when it can't be used yet and
/// says why underneath, so the feature is never hidden.
struct AskClaudeButton: View {
    let title: LocalizedStringKey
    let ask: ClaudeAsk.Ask
    /// Why the button can't be used yet, such as "Save first"; nil when it can.
    var unavailable: String?
    /// Points at the button once, after Claude is set up.
    var tip: ClaudeTip?
    /// Shows `unavailable` under the button. Off when the button sits in a section header and
    /// the reason goes in the footer instead (`ClaudeUnavailableNote`).
    var showsReason = true

    @Environment(\.modelContext) private var context
    @State private var outcome: ClaudeAsk.Outcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                tip?.invalidate(reason: .actionPerformed)
                outcome = ClaudeAsk.send(ask, container: context.container)
            } label: {
                Label {
                    Text(title)
                } icon: {
                    // The sparkle stays orange, so it still reads as Claude while it waits.
                    Image(systemName: "sparkles").foregroundStyle(.claude)
                }
            }
            .buttonStyle(.bordered)
            .tint(unavailable == nil ? .claude : .gray)
            .foregroundStyle(unavailable == nil ? AnyShapeStyle(.claude) : AnyShapeStyle(.secondary))
            .disabled(unavailable != nil)
            .help(unavailable ?? String(localized: "Queue this for Claude; start it from AI Activity → Requests and review the result in Civa"))
            // Outside the orange style, so the tip's text keeps its normal color.
            .popoverTip(tip, arrowEdge: .top)
            .tipImageStyle(Color.claude)
            if showsReason, let unavailable {
                Text(unavailable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .claudeAskAlerts($outcome)
    }
}

/// Why a Claude button in the section header can't be used yet, shown in the section footer.
struct ClaudeUnavailableNote: View {
    let reason: String?

    var body: some View {
        if let reason {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").foregroundStyle(.claude)
                Text(reason)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        AskClaudeButton(title: "Improve with Claude", ask: .init(kind: .improveBullets, category: .experience, targetID: UUID(), targetTitle: "iOS Engineer"))
        AskClaudeButton(title: "Improve with Claude", ask: .init(kind: .improveBullets, category: .experience, targetID: UUID(), targetTitle: "iOS Engineer"), unavailable: "Save your changes first")
    }
    .padding()
    .previewEnvironment()
}
