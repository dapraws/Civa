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
        if DataMode.usesSampleData { return ModelContainer.preview }
        #endif
        return try ModelContainer.civa()
    }

    init() {
        ClaudeTip.configure()
        ClaudeRequestNotice.shared.configure()
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
            }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Show Welcome") { Onboarding.shared.request = .welcome }
                Button("Show Getting Started") { Onboarding.shared.request = .gettingStarted }
            }
        }
    }
}
