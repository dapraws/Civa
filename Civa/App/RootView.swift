//
//  RootView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var navigation = AppNavigation()
    /// The section clicked while the unsaved-changes prompt is up.
    @State private var pendingSection: AppSection?
    private var bridge = ClaudeBridge.shared
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }) private var claudeProposals: [ClaudeProposal]
    @Query(filter: #Predicate<ClaudeRequest> { $0.statusRaw == "failed" }) private var failedRequests: [ClaudeRequest]

    var body: some View {
        NavigationSplitView {
            List(
                AppSection.visible(claudeEnabled: bridge.isEnabled),
                selection: Binding(changes.selection($navigation.section, pending: $pendingSection))
            ) { section in
                if section == .aiActivity {
                    let count = claudeProposals.count + failedRequests.count
                    Label {
                        Text(section.title)
                    } icon: {
                        Image(systemName: section.systemImage).foregroundStyle(.claude)
                    }
                    .badge(count > 0 ? Text("\(count)").foregroundStyle(.claude).bold() : nil)
                } else {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200)
            #if DEBUG
            .safeAreaInset(edge: .bottom) {
                if DataMode.usesSampleData {
                    Label("Sample Data", systemImage: "testtube.2")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .help("Debug builds start with fresh sample data. Switch in Settings → Developer.")
                }
            }
            #endif
        } detail: {
            detail
                .navigationTitle(navigation.section.title)
        }
        .environment(navigation)
        // Wide enough for the Career Profile tabs and the resume editor's three columns at their minimums.
        .frame(minWidth: 1100, minHeight: 640)
        .onChange(of: bridge.isEnabled, initial: true) { _, enabled in
            ClaudeTip.isConnected = enabled
            if !enabled, navigation.section == .aiActivity { navigation.section = .dashboard }
        }
        .unsavedChangesAlert(changes)
        // Closing the window quits; keep it open until edits are saved or reverted.
        .windowDismissBehavior(changes.hasUnsavedChanges ? .disabled : .automatic)
    }

    @ViewBuilder
    private var detail: some View {
        let section = navigation.section
        switch section {
        case .dashboard:
            DashboardView()
        case .careerProfile:
            CareerProfileView()
        case .documents:
            DocumentsView()
        case .resumes:
            ResumesView()
        case .applications:
            ApplicationsView()
        case .aiActivity:
            AIActivityView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
