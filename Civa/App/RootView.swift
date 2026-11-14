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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @State private var navigation = AppNavigation()
    /// The section clicked while the unsaved-changes prompt is up.
    @State private var pendingSection: AppSection?
    private var bridge = ClaudeBridge.shared
    private var notice = ClaudeRequestNotice.shared
    private var onboarding = Onboarding.shared
    @State private var welcomeChoice: WelcomeSheet.Choice?
    @FocusState private var isSidebarFocused: Bool
    @State private var ovi = OviEngine()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    /// Below `autoHideWidth` the sidebar hides and slides in over the page on hover, so Civa fits
    /// half of any Mac screen.
    @State private var isNarrow = false
    @State private var showsPeek = false
    private static let autoHideWidth: CGFloat = 1000
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }) private var claudeProposals: [ClaudeProposal]
    /// Waiting and failed requests: both need the user to start them in Claude.
    @Query(filter: #Predicate<ClaudeRequest> { $0.statusRaw == "pending" || $0.statusRaw == "failed" })
    private var openRequests: [ClaudeRequest]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 204, ideal: 204, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.canvas)
                .toolbar(removing: .title)
                // The title bar keeps only the window controls and the sidebar toggle (DESIGN.md §2).
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < Self.autoHideWidth } action: { narrow in
            isNarrow = narrow
            showsPeek = false
            withAnimation(.snappy) { columnVisibility = narrow ? .detailOnly : .all }
        }
        .overlay(alignment: .leading) {
            if isNarrow, columnVisibility == .detailOnly {
                SidebarPeek(isShown: $showsPeek, hasTip: isOviNoticing) { sidebar }
            }
        }
        .onChange(of: navigation.section) { showsPeek = false }
        .overlay(alignment: .top) {
            if let title = notice.banner {
                ClaudeRequestBanner(title: title, onOpen: notice.open) { notice.banner = nil }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: notice.banner)
        .onChange(of: notice.opensRequests) { _, opens in
            guard opens else { return }
            notice.opensRequests = false
            // Like a sidebar click: unsaved edits are saved or discarded first.
            changes.perform {
                navigation.aiActivityTab = .requests
                navigation.section = .aiActivity
            }
        }
        .sheet(isPresented: Binding { onboarding.showsWelcome } set: { onboarding.showsWelcome = $0 }, onDismiss: welcomeClosed) {
            WelcomeSheet { choice in
                welcomeChoice = choice
                onboarding.showsWelcome = false
            }
        }
        #if DEBUG
        // Manual checks: -CivaShowHelp YES, -CivaWindowWidth 640
        .onAppear {
            if UserDefaults.standard.bool(forKey: "CivaShowHelp") { openWindow(id: "help") }
            let width = UserDefaults.standard.double(forKey: "CivaWindowWidth")
            if width > 0, let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) {
                window.setContentSize(NSSize(width: width, height: 800))
            }
        }
        #endif
        .onChange(of: onboarding.request) { _, request in
            guard let request else { return }
            onboarding.request = nil
            // Switching pages under an open sheet would throw away what's in the sheet.
            if request == .settings, NSApp.windows.contains(where: { $0.attachedSheet != nil }) { return }
            changes.perform {
                navigation.section = .dashboard
                switch request {
                case .welcome: onboarding.showsWelcome = true
                case .gettingStarted: UserDefaults.standard.set(false, forKey: Onboarding.checklistHiddenKey)
                case .settings: navigation.section = .settings
                }
            }
        }
        // A hidden sidebar pauses Ovi, except when it only waits for a hover (the edge shows a dot).
        .background { OviWatcher(isSidebarCollapsed: columnVisibility == .detailOnly && !isNarrow) }
        #if DEBUG
        .onAppear {
            if let raw = UserDefaults.standard.string(forKey: "CivaOviPreview"), let tip = OviTipID(rawValue: raw) {
                ovi.showPreview(tip, open: UserDefaults.standard.bool(forKey: "CivaOviOpen"))
            }
        }
        #endif
        .environment(navigation)
        .environment(ovi)
        .civaWindowStyle()
        // Half of a 1280 pt screen, the narrowest common Mac, so Civa fits side by side anywhere.
        .frame(minWidth: 640, minHeight: 600)
        .onChange(of: bridge.isEnabled, initial: true) { _, enabled in
            ClaudeTip.isConnected = enabled
            if !enabled, navigation.section == .aiActivity { navigation.section = .dashboard }
        }
        .unsavedChangesAlert(changes)
        .workspaceSwitchAlert(changes)
        // Closing the window quits; keep it open until edits are saved or reverted.
        .windowDismissBehavior(changes.hasUnsavedChanges ? .disabled : .automatic)
    }

    /// DESIGN.md §8.1: wordmark, the sections, Settings set apart, then Ovi's perch (Plan 3) and
    /// whose workspace this is.
    private var sidebar: some View {
        let sections = AppSection.visible(claudeEnabled: bridge.isEnabled)
        let selection = changes.selection($navigation.section, pending: $pendingSection)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Civa")
                .font(.wordmark)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Space.m)
            .padding(.bottom, Space.m)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(sections.filter { $0 != .settings }) { item(for: $0, selection: selection) }
            }
            item(for: .settings, selection: selection)
                .padding(.top, Space.l)
            Spacer(minLength: Space.l)
            OviPerch(perform: performOviAction, openWhy: { _ in
                HelpNavigator.shared.topic = "ovi"
                openWindow(id: "help")
            })
                .padding(.leading, 2)
                .padding(.bottom, Space.s)
            WorkspaceLabel()
                .padding(.horizontal, Space.m)
        }
        .padding(.horizontal, 10)
        .padding(.top, Space.s)
        .padding(.bottom, Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sidebar)
        .focusable()
        .focused($isSidebarFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(-1, in: sections, selection: selection) }
        .onKeyPress(.downArrow) { step(1, in: sections, selection: selection) }
    }

    /// Ovi's bubble action (tip engine spec §4.4). Resume changes go through the open resume, so
    /// its editor shows them as unsaved edits that Revert can undo.
    private func performOviAction(_ action: OviAction) {
        switch action {
        case .tailorCopy(let id):
            let application = navigation.openRecordID
            changes.perform {
                navigation.tailorApplicationID = application
                navigation.tailorResumeID = id
                navigation.section = .resumes
            }
        case .setFontSize10, .useShortDates:
            guard let editor = changes.active as? RecordEditor<Resume> else { return }
            action.apply(to: editor)
        }
    }

    private func item(for section: AppSection, selection: Binding<AppSection>) -> some View {
        SidebarItem(
            section,
            isSelected: selection.wrappedValue == section,
            badge: section == .aiActivity ? claudeProposals.count + openRequests.count : nil
        ) {
            isSidebarFocused = true
            selection.wrappedValue = section
        }
        .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isSidebarFocused && selection.wrappedValue == section)
    }

    private var isOviNoticing: Bool {
        if case .noticing = ovi.state { true } else { false }
    }

    private func step(_ offset: Int, in sections: [AppSection], selection: Binding<AppSection>) -> KeyPress.Result {
        guard let index = sections.firstIndex(of: selection.wrappedValue),
              sections.indices.contains(index + offset) else { return .ignored }
        selection.wrappedValue = sections[index + offset]
        return .handled
    }

    /// Acts on the welcome choice once the sheet is gone, so a file panel can open.
    private func welcomeClosed() {
        UserDefaults.standard.set(true, forKey: Onboarding.welcomeShownKey)
        let choice = welcomeChoice
        welcomeChoice = nil
        switch choice {
        case .importCV: onboarding.importKind = .cv
        case .importLinkedIn: onboarding.importKind = .linkedInExport
        case .addByHand:
            changes.perform {
                navigation.profileCategory = .personal
                navigation.section = .careerProfile
            }
        case .lookAround, nil: break
        }
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
