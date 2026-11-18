//
//  CivaApp.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import SwiftData

struct CivaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container = Result {
        #if DEBUG
        // Debug builds run on fresh sample data unless Settings → Developer says otherwise.
        switch DataMode.current {
        case .sample: return ModelContainer.preview
        case .empty: return try ModelContainer.civa(inMemory: true)
        case .real: break
        }
        #endif
        let workspaces = WorkspaceRegistry.shared
        let container = try ModelContainer.civa(storeURL: workspaces.storeURL(for: workspaces.current))
        PersonalInfo.removeInvisibles(in: container.mainContext)
        // The first workspace takes the profile's name.
        if let name = try? container.mainContext.fetch(FetchDescriptor<PersonalInfo>()).first?.fullName {
            workspaces.nameOriginalIfNeeded(name)
        }
        return container
    }

    init() {
        CivaFonts.register()
        #if DEBUG
        if DataMode.current == .empty {
            // A new user has seen nothing yet.
            for key in [Onboarding.welcomeShownKey, Onboarding.checklistHiddenKey] { UserDefaults.standard.removeObject(forKey: key) }
        }
        #endif
        CivaTips.configure()
    }

    var body: some Scene {
        // Single window: Civa is one workspace, and ⌘N is free for new records.
        Window("Civa", id: "main") {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(appDelegate.changes)
                    .onAppear {
                        ClaudeBridge.shared.handler = { ClaudeTools.answer($0, container: container) }
                        ClaudeBridge.shared.startIfEnabled()
                    }
            case .failure(let error):
                StoreErrorView(error: error)
                    .civaWindowStyle()
            }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsCommand()
                WorkspaceMenu()
            }
            CommandGroup(replacing: .help) {
                HelpMenu()
            }
        }

        Window("Civa Help", id: HelpMenu.windowID) {
            HelpView()
                .civaWindowStyle()
        }
        .defaultSize(width: 860, height: 600)
    }
}

/// Help menu items. A view so the button can open the Help window.
private struct HelpMenu: View {
    static let windowID = "help"
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Civa Help") { openWindow(id: Self.windowID) }
            .keyboardShortcut("?")
        Divider()
        Button("Show Welcome") { Onboarding.shared.request = .welcome }
        Button("Show Getting Started") { Onboarding.shared.request = .gettingStarted }
    }
}
