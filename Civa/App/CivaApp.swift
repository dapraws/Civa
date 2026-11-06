//
//  CivaApp.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import SwiftData

@main
struct CivaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container = Result {
        #if DEBUG
        // Sample data in memory for manual checks: -CivaSampleData YES
        if UserDefaults.standard.bool(forKey: "CivaSampleData") { return ModelContainer.preview }
        #endif
        return try ModelContainer.civa()
    }

    var body: some Scene {
        // Single window: Civa is one workspace, and ⌘N is free for new records.
        Window("Civa", id: "main") {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(appDelegate.changes)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
        .defaultSize(width: 1100, height: 720)
    }
}
