//
//  DashboardView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Home page: a short summary of the profile and applications, not an analytics page (FR-002).
struct DashboardView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation

    @Query private var personalInfo: [PersonalInfo]
    @Query private var experiences: [Experience]
    @Query private var education: [Education]
    @Query private var projects: [Project]
    @Query private var achievements: [Achievement]
    @Query private var certifications: [Certification]
    @Query private var skills: [Skill]
    @Query private var applications: [JobApplication]

    var body: some View {
        let summary = DashboardSummary(
            personalInfo: personalInfo,
            experiences: experiences,
            education: education,
            projects: projects,
            achievements: achievements,
            certifications: certifications,
            skills: skills,
            applications: applications
        )
        if summary.isEmpty {
            ContentUnavailableView {
                Label("Start Your Career Profile", systemImage: AppSection.careerProfile.systemImage)
            } description: {
                Text("Add your details once, then reuse them for every resume. Everything stays on this Mac.")
            } actions: {
                ImportMenu()
                Button("Add Personal Information") { open(.personal) }
                Button("Add Experience", action: addExperience)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    quickActions
                    ClaudeSetupCard()
                    ClaudeInboxCard()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), alignment: .top)], spacing: 16) {
                        profileCard(summary)
                        applicationsCard(summary)
                    }
                    recentActivityCard(summary)
                }
                .padding(20)
                .frame(maxWidth: 960, alignment: .leading)
            }
        }
    }

    private var quickActions: some View {
        HStack {
            Button(action: addExperience) {
                Label("Add Experience", systemImage: "plus")
            }
        }
    }

    private func profileCard(_ summary: DashboardSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                let total = ProfileCategory.allCases.count
                let filled = summary.filledCategories.count
                ProgressView(value: Double(filled), total: Double(total)) {
                    Text("\(filled) of \(total) sections filled in")
                }
                if !summary.missingCategories.isEmpty {
                    Text("Still empty:")
                        .foregroundStyle(.secondary)
                    ForEach(summary.missingCategories) { category in
                        Button(category.title) { open(category) }
                            .buttonStyle(.link)
                    }
                }
                if summary.needsReviewCount > 0 {
                    Divider()
                    CountRow(count: summary.needsReviewCount) { ReviewBadge() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Career Profile", systemImage: AppSection.careerProfile.systemImage)
        }
    }

    private func applicationsCard(_ summary: DashboardSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                if summary.applicationTotal == 0 {
                    Text("No applications yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.applicationCounts.filter { $0.count > 0 }, id: \.status) { item in
                        CountRow(count: item.count) { Text(item.status.title) }
                    }
                }
                Button("View Applications") { go { navigation.section = .applications } }
                    .buttonStyle(.link)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Applications", systemImage: AppSection.applications.systemImage)
        }
    }

    private func recentActivityCard(_ summary: DashboardSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.recentActivity) { activity in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                            Text(activity.kind)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(activity.date, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Recent Activity", systemImage: "clock")
        }
    }

    private func open(_ category: ProfileCategory) {
        go {
            navigation.profileCategory = category
            navigation.section = .careerProfile
        }
    }

    private func addExperience() {
        go {
            navigation.profileCategory = .professional
            navigation.startsNewRecord = true
            navigation.section = .careerProfile
        }
    }

    /// Dashboard never holds unsaved edits, but navigation always goes through the guard.
    private func go(_ action: @escaping () -> Void) {
        changes.perform(action)
    }
}

/// A label with its count pushed to the trailing edge.
private struct CountRow<Label: View>: View {
    let count: Int
    @ViewBuilder let label: Label

    var body: some View {
        HStack {
            label
            Spacer()
            Text(count, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .frame(width: 900, height: 640)
    .previewEnvironment()
}
