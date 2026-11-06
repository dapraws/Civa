//
//  StoreErrorView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import SwiftUI

/// Shown when the data store can't be opened, instead of crashing (NFR-006).
struct StoreErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Civa Couldn't Open Your Data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Quit and reopen Civa to try again.\n\n\(error.localizedDescription)")
        } actions: {
            Button("Quit Civa") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    StoreErrorView(error: CocoaError(.fileReadCorruptFile))
}
