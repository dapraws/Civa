//
//  RootView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Placeholder until the Phase 1 sidebar shell replaces it.
struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "Civa",
            systemImage: "person.text.rectangle",
            description: Text("Your career workspace is being set up.")
        )
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    RootView()
}
