//
//  RootView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

struct RootView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var section: AppSection = .dashboard
    /// What the sidebar highlights; `section` follows once unsaved changes are resolved.
    @State private var highlightedSection: AppSection = .dashboard

    var body: some View {
        NavigationSplitView {
            List(
                AppSection.allCases,
                selection: Binding(changes.selection($highlightedSection) { section = $0 })
            ) { section in
                Label(section.title, systemImage: section.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail
                .navigationTitle(section.title)
        }
        .frame(minWidth: 900, minHeight: 560)
        .unsavedChangesAlert(changes)
        // Closing the window quits; keep it open until edits are saved or reverted.
        .windowDismissBehavior(changes.hasUnsavedChanges ? .disabled : .automatic)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .dashboard:
            ContentUnavailableView(
                "Your Dashboard",
                systemImage: section.systemImage,
                description: Text("A summary of your profile and applications will appear here.")
            )
        case .careerProfile:
            ContentUnavailableView(
                "Your Career Profile",
                systemImage: section.systemImage,
                description: Text("Your experience, education, and projects will appear here.")
            )
        case .resumes:
            ContentUnavailableView(
                "Resumes Aren't Available Yet",
                systemImage: section.systemImage,
                description: Text("You'll build ATS-friendly resumes from your career profile here.")
            )
        case .applications:
            ContentUnavailableView(
                "Your Applications",
                systemImage: section.systemImage,
                description: Text("Track the jobs you apply for here.")
            )
        case .settings:
            ContentUnavailableView(
                "Nothing to Set Up Yet",
                systemImage: section.systemImage,
                description: Text("Privacy and integration settings will appear here.")
            )
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
