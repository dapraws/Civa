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
    @AppStorage("ResumeShowsGuides") private var showsGuides = false
    @State private var hoveredGuide: ResumeRenderer.Guide?
    @State private var flashedGuide: ResumeRenderer.Guide?
    @State private var flashCount = 0
    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(\.closeRecordEditor) private var closeEditor
    @Query(filter: #Predicate<ClaudeProposal> { $0.kindRaw == "resumeEdit" && $0.statusRaw == "pending" }) private var claudeProposals: [ClaudeProposal]
    @Query(sort: \JobApplication.updatedAt, order: .reverse) private var applications: [JobApplication]

    init(editor: RecordEditor<Resume>) {
        self.editor = editor
        // A new resume starts on its name, which it needs before it can be saved.
        _selection = State(initialValue: editor.isNew ? .info : .header)
    }

    var body: some View {
        let document = editor.binding(\.document)
        let guides: Set<ResumeRenderer.Guide> = showsGuides
            ? Set(ResumeRenderer.Guide.allCases)
            : Set([hoveredGuide, flashedGuide].compactMap(\.self))
        let data = ResumeRenderer.pdf(for: document.wrappedValue, guides: guides)
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
                PDFPreview(data: data)
                    .frame(width: min(max(previewWidth, previewRange.lowerBound), previewRange.upperBound))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                titleRow
                if editor.record.isClaudeDraft {
                    ClaudeDraftBanner(editor: editor)
                }
                ResumeFormatBar(
                    format: document.format, pageCount: PDFDocument(data: data)?.pageCount ?? 0, showsGuides: $showsGuides
                ) { guide, inside in
                    if inside {
                        hoveredGuide = guide
                    } else if hoveredGuide == guide {
                        hoveredGuide = nil
                    }
                }
                Divider()
            }
        }
        // Changing a value shows its guide for a moment, wherever the change came from.
        .onChange(of: editor.record.document.format.margins) { flash(.margins) }
        .onChange(of: editor.record.document.format.sideMargins) { flash(.margins) }
        .onChange(of: editor.record.document.format.sectionSpacing) { flash(.sectionSpacing) }
        .onChange(of: editor.record.document.format.entrySpacing) { flash(.entrySpacing) }
        .onChange(of: editor.record.document.format.lineSpacing) { flash(.lineSpacing) }
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
    /// DESIGN.md §8.6: a compact 40 pt row. Back and the resume's name (the one place a record name
    /// uses the smaller serif), then Claude, suggested changes, History and Export.
    private var titleRow: some View {
        HStack(spacing: Space.s) {
            Button("Back", systemImage: "chevron.left") { changes.perform(closeEditor) }
                .labelStyle(.iconOnly)
                .civaButton(.textLink)
                .frame(width: Size.minTarget, height: Size.minTarget)
                .keyboardShortcut("[", modifiers: .command)
                .help("Back to Resumes (⌘[)")
            Text(editor.title)
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.l)
            let claudeCount = pendingClaude.count
            if claudeCount > 0 {
                Button("\(claudeCount) From Claude", systemImage: "sparkles") { isShowingClaude = true }
                    .civaButton(.claude, size: .small)
                    .help("Wording Claude suggested for this resume")
            }
            askClaudeMenu
            let suggestionCount = SuggestedChanges.suggestions(
                for: editor.record.document, from: ProfileSource.current(in: context)
            ).count
            if suggestionCount > 0 {
                Button("\(suggestionCount) Suggested", systemImage: "arrow.triangle.2.circlepath") { isShowingSuggestions = true }
                    .civaButton(.secondary, size: .small)
                    .help("Changes from your Career Profile that this resume doesn't have yet")
            }
            Button("History", systemImage: "clock.arrow.circlepath") { isShowingHistory = true }
                .civaButton(.secondary, size: .small)
                .disabled(editor.isNew)
                .help(editor.isNew ? "Save the resume to start its history" : "Versions of this resume")
            ResumeExportButton(editor: editor)
                .civaButton(.primary, size: .small)
        }
        .padding(.horizontal, Space.l)
        .frame(height: 40)
        .background(Color.canvas)
    }

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
        }
        .menuStyle(.button)
        .civaButton(.claude, size: .small)
        .fixedSize()
        .help(editor.isNew || editor.isDirty ? "Saves the resume, then asks Claude Desktop to suggest wording; you review it here" : "Ask Claude Desktop to suggest wording; you review it here")
        .popoverTip(ClaudeTip.askResume, arrowEdge: .bottom)
        .tipImageStyle(Color.claude)
    }

    private func ask(_ kind: ClaudeRequest.Kind, application: JobApplication? = nil) {
        // Saves unsaved edits first, so Claude reads what's on screen; a failed save shows its error and stops here.
        guard editor.saveIfNeeded() else { return }
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

extension ResumeEditorView {
    /// Shows a guide, then hides it 1.5 seconds after the last change.
    private func flash(_ guide: ResumeRenderer.Guide) {
        flashedGuide = guide
        flashCount += 1
        let count = flashCount
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if flashCount == count { flashedGuide = nil }
        }
    }
}

#Preview {
    ResumeEditorView(editor: .preview())
        .frame(width: 1100, height: 700)
        .previewEnvironment()
}
