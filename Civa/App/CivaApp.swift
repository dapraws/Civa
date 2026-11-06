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
    private let container = Result { try ModelContainer.civa() }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}
