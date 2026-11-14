//
//  CareerProfileView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Career Profile page (DESIGN.md §8.3): the title row, then the six categories as tabs.
struct CareerProfileView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    /// The tab clicked while the unsaved-changes prompt is up.
    @State private var pendingCategory: ProfileCategory?
    /// The current tab's add action, handed up by its record list.
    @State private var addAction: PageAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(String(localized: "Career Profile")) {
                ImportMenu(showsTitle: true)
                    .menuStyle(.button)
                    .civaButton(.secondary)
                    .fixedSize()
                PageActionButton(action: addAction)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, 20)
            // Scrolls sideways when a narrow window can't fit all six tabs.
            ScrollView(.horizontal) {
                SegmentedTabs(
                    ProfileCategory.allCases,
                    selection: changes.selection(Bindable(navigation).profileCategory, pending: $pendingCategory),
                    title: \.shortTitle
                )
                .padding(.horizontal, Space.xl)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .padding(.top, Space.m)
            .padding(.bottom, Space.m)
            Rectangle().fill(Color.hairline).frame(height: 1)
            page
                .id(navigation.profileCategory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.canvas)
        .onPreferenceChange(PageActionKey.self) { action in
            MainActor.assumeIsolated { addAction = action }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.profileCategory {
        case .personal: PersonalInfoView()
        case .professional: ExperienceList(kind: .professional)
        case .education: EducationList()
        case .organizational: ExperienceList(kind: .organizational)
        case .projects: ProjectList()
        case .other: OtherInformationView()
        }
    }
}

#Preview {
    NavigationStack {
        CareerProfileView()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}
