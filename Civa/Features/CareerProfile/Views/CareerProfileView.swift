//
//  CareerProfileView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Career Profile page: the six categories as tabs in the toolbar.
struct CareerProfileView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation
    /// The tab clicked while the unsaved-changes prompt is up.
    @State private var pendingCategory: ProfileCategory?

    var body: some View {
        page
            .id(navigation.profileCategory)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(
                        "Category",
                        selection: changes.selection(Bindable(navigation).profileCategory, pending: $pendingCategory)
                    ) {
                        ForEach(ProfileCategory.allCases) { category in
                            Text(category.shortTitle)
                                .accessibilityLabel(category.title)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                ToolbarItem(placement: .primaryAction) {
                    ImportCVButton()
                }
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
