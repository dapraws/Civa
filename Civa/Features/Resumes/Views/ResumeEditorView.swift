//
//  ResumeEditorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftData
import SwiftUI

/// Outline, fields, and live preview, with draggable dividers between them (FR-032, FR-033).
struct ResumeEditorView: View {
    let editor: RecordEditor<Resume>
    @State private var selection: ResumeOutlineItem?
    @State private var outlineWidth: CGFloat = 210
    @State private var previewWidth: CGFloat = 540
    @State private var isShowingHistory = false
    @State private var isShowingSuggestions = false
    @State private var isShowingClaude = false
    @State private var askOutcome: ClaudeAsk.Outcome?
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ClaudeProposal> { $0.kindRaw == "resumeEdit" && $0.statusRaw == "pending" }) private var claudeProposals: [ClaudeProposal]
    @Query(sort: \JobApplication.updatedAt, order: .reverse) private var applications: [JobApplication]

    init(editor: RecordEditor<Resume>) {
        self.editor = editor
        // A new resume starts on its name, which it needs before it can be saved.
        _selection = State(initialValue: editor.isNew ? .info : .header)
    }

    var body: some View {
        let document = editor.binding(\.document)
        GeometryReader { proxy in
            // The fields column takes what's left and keeps at least 280 pt.
            let previewRange = 280...max(280, proxy.size.width - outlineWidth - 282)
            HStack(spacing: 0) {
                ResumeOutlineView(document: document, selection: $selection)
                    .frame(width: outlineWidth)
                ColumnDivider(width: $outlineWidth, range: 170...340, direction: 1)
                ResumeItemForm(editor: editor, document: document, selection: $selection)
                    .frame(maxWidth: .infinity)
                ColumnDivider(width: $previewWidth, range: previewRange, direction: -1)
                ResumePreviewPane(document: document)
                    .frame(width: min(max(previewWidth, previewRange.lowerBound), previewRange.upperBound))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if editor.record.isClaudeDraft {
                ClaudeDraftBanner(editor: editor)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                let claudeCount = pendingClaude.count
                if claudeCount > 0 {
                    Button {
                        isShowingClaude = true
                    } label: {
                        Label("\(claudeCount) From Claude", systemImage: "sparkles")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("Wording Claude suggested for this resume")
                }
                askClaudeMenu
                let suggestionCount = SuggestedChanges.suggestions(
                    for: editor.record.document, from: ProfileSource.current(in: context)
                ).count
                if suggestionCount > 0 {
                    Button {
                        isShowingSuggestions = true
                    } label: {
                        Label("\(suggestionCount) Suggested", systemImage: "sparkles")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("Changes from your Career Profile that this resume doesn't have yet")
                }
                Button("History", systemImage: "clock.arrow.circlepath") { isShowingHistory = true }
                    .disabled(editor.isNew)
                    .help(editor.isNew ? "Save the resume to start its history" : "Versions of this resume")
                ResumeExportButton(editor: editor)
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            ResumeHistorySheet(editor: editor)
        }
        .sheet(isPresented: $isShowingSuggestions) {
            SuggestedChangesSheet(document: document, source: ProfileSource.current(in: context))
        }
        .sheet(isPresented: $isShowingClaude) {
            ClaudeResumeProposalsSheet(editor: editor, proposals: pendingClaude)
        }
        .claudeAskAlerts($askOutcome)
        #if DEBUG
        // Manual checks: -CivaShowHistory YES opens History.
        .onAppear {
            isShowingHistory = UserDefaults.standard.bool(forKey: "CivaShowHistory") && !editor.isNew
            // -CivaShowSuggestions YES opens Suggested Changes.
            isShowingSuggestions = UserDefaults.standard.bool(forKey: "CivaShowSuggestions")
        }
        #endif
    }
}

extension ResumeEditorView {
    private var pendingClaude: [ClaudeProposal] {
        claudeProposals.filter { $0.targetID == editor.record.id }
    }

    /// Requests for Claude about this resume (FR-072).
    private var askClaudeMenu: some View {
        Menu {
            Button("Write a Summary") { ask(.writeSummary) }
            Menu("Tailor to a Job") {
                let jobs = applications.filter { !$0.jobDescription.isBlank }
                if jobs.isEmpty {
                    Text("Add a job description to an application first")
                }
                ForEach(jobs) { application in
                    Button("\(application.position) at \(application.company)") { ask(.tailorResume, application: application) }
                }
            }
        } label: {
            Label("Ask Claude", systemImage: "sparkles")
        }
        .disabled(editor.isNew || editor.isDirty)
        .help(editor.isNew || editor.isDirty ? "Save the resume first, then ask Claude" : "Ask Claude Desktop to suggest wording; you review it here")
    }

    private func ask(_ kind: ClaudeRequest.Kind, application: JobApplication? = nil) {
        askOutcome = ClaudeAsk.send(
            .init(
                kind: kind, category: .resumes, targetID: editor.record.id, targetTitle: editor.record.displayTitle,
                applicationID: application?.id, makesCopy: kind == .tailorResume
            ),
            container: context.container
        )
    }
}

/// The PDF preview with the format bar on top.
private struct ResumePreviewPane: View {
    @Binding var document: ResumeDocument

    var body: some View {
        let data = ResumeRenderer.pdf(for: document)
        VStack(spacing: 0) {
            ResumeFormatBar(format: $document.format, pageCount: PDFDocument(data: data)?.pageCount ?? 0)
            Divider()
            PDFPreview(data: data)
        }
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1100, height: 700)
        .previewEnvironment()
}
