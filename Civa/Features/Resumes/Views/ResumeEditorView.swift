//
//  ResumeEditorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftData
import SwiftUI
import TipKit

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
            // The fields column takes what's left and keeps at least 320 pt, so labels and values don't overlap.
            let previewRange = 280...max(280, proxy.size.width - outlineWidth - 322)
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
                    .buttonStyle(.borderedProminent)
                    .tint(.claude)
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
                        Label("\(suggestionCount) Suggested", systemImage: "arrow.triangle.2.circlepath")
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
            // -CivaShowClaude YES opens Claude's suggestions.
            isShowingClaude = UserDefaults.standard.bool(forKey: "CivaShowClaude")
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
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.claude)
        }
        .tint(.claude)
        .disabled(editor.isNew || editor.isDirty)
        .help(editor.isNew || editor.isDirty ? "Save the resume first, then ask Claude" : "Ask Claude Desktop to suggest wording; you review it here")
        .popoverTip(ClaudeTip.askResume, arrowEdge: .bottom)
        .tipImageStyle(Color.claude)
    }

    private func ask(_ kind: ClaudeRequest.Kind, application: JobApplication? = nil) {
        ClaudeTip.askResume.invalidate(reason: .actionPerformed)
        askOutcome = ClaudeAsk.send(
            .init(
                kind: kind, category: .resumes, targetID: editor.record.id, targetTitle: editor.record.displayTitle,
                applicationID: application?.id, makesCopy: kind == .tailorResume
            ),
            container: context.container
        )
    }
}

/// The PDF preview with the format ribbon on top. Adjusting spacing shows red distance guides
/// on the preview for a moment; the ruler button keeps them on. The export never has them.
private struct ResumePreviewPane: View {
    @Binding var document: ResumeDocument
    @AppStorage("ResumeShowsGuides") private var showsGuides = false
    @State private var hovered: ResumeRenderer.Guide?
    @State private var flashed: ResumeRenderer.Guide?
    @State private var flashCount = 0

    var body: some View {
        let guides: Set<ResumeRenderer.Guide> = showsGuides ? Set(ResumeRenderer.Guide.allCases) : Set([hovered, flashed].compactMap(\.self))
        let data = ResumeRenderer.pdf(for: document, guides: guides)
        VStack(spacing: 0) {
            ResumeFormatBar(
                format: $document.format, pageCount: PDFDocument(data: data)?.pageCount ?? 0, showsGuides: $showsGuides
            ) { guide, inside in
                if inside {
                    hovered = guide
                } else {
                    hovered = nil
                    flash(guide)
                }
            }
            Divider()
            PDFPreview(data: data)
        }
        .onChange(of: document.format.margins) { flash(.margins) }
        .onChange(of: document.format.sectionSpacing) { flash(.sectionSpacing) }
        .onChange(of: document.format.lineSpacing) { flash(.lineSpacing) }
    }

    /// Shows a guide, then hides it 1.5 seconds after the last change.
    private func flash(_ guide: ResumeRenderer.Guide) {
        flashed = guide
        flashCount += 1
        let count = flashCount
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if flashCount == count { flashed = nil }
        }
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1100, height: 700)
        .previewEnvironment()
}
