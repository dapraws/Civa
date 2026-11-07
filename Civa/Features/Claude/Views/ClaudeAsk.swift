//
//  ClaudeAsk.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import SwiftData
import SwiftUI

/// Queues a request for Claude (FR-072) and brings up Claude Desktop. MCP can't start Claude
/// from Civa, so the user sends one short prompt there; it's copied to the clipboard.
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
        /// With the copy Claude will work on, when the request made one.
        case queued(copy: Copy?)
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
        context.insert(ClaudeRequest(kind: ask.kind, targetID: ask.targetID, targetTitle: ask.targetTitle, applicationID: ask.applicationID))
        try? context.save()
        openClaude()
        return .queued(copy: nil)
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
        context.insert(ClaudeRequest(kind: ask.kind, targetID: copy.id, targetTitle: copy.displayTitle, applicationID: ask.applicationID))
        do {
            try context.save()
        } catch {
            return .failed(error.localizedDescription)
        }
        openClaude()
        return .queued(copy: .init(id: copy.id, title: copy.displayTitle))
    }

    /// Copies the prompt and opens Claude Desktop.
    @MainActor
    static func openClaude() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        ClaudeDesktopConfig.openClaude()
    }
}

/// The alerts that follow an Ask Claude button: not set up, not allowed, or sent.
struct ClaudeAskAlerts: ViewModifier {
    @Binding var outcome: ClaudeAsk.Outcome?
    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content.alert(item: $outcome) { outcome in
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
            case .queued(let copy?):
                Alert(
                    title: Text("Sent to Claude"),
                    message: Text("Claude will tailor “\(copy.title)”, a new copy, so the original stays as it is. In Claude Desktop, send “\(ClaudeAsk.prompt)” It's on your clipboard."),
                    primaryButton: .default(Text("Open Copy")) { navigation.recordToOpen = copy.id },
                    secondaryButton: .cancel(Text("Not Now"))
                )
            case .failed(let reason):
                Alert(title: Text("Civa Couldn't Send the Request"), message: Text(reason))
            case .queued(nil):
                Alert(
                    title: Text("Sent to Claude"),
                    message: Text("In Claude Desktop, send “\(ClaudeAsk.prompt)” It's on your clipboard. Claude's answer comes back to Civa for your review.")
                )
            }
        }
    }
}

extension View {
    func claudeAskAlerts(_ outcome: Binding<ClaudeAsk.Outcome?>) -> some View {
        modifier(ClaudeAskAlerts(outcome: outcome))
    }
}

/// A button that queues one request.
struct AskClaudeButton: View {
    let title: LocalizedStringKey
    let ask: ClaudeAsk.Ask
    var disabled = false

    @Environment(\.modelContext) private var context
    @State private var outcome: ClaudeAsk.Outcome?

    var body: some View {
        Button {
            outcome = ClaudeAsk.send(ask, container: context.container)
        } label: {
            Label(title, systemImage: "sparkles")
        }
        .disabled(disabled)
        .help(disabled ? "Save first, then ask Claude" : "Queue this for Claude Desktop; you review the result in Civa")
        .claudeAskAlerts($outcome)
    }
}
