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
    @Query(sort: \Resume.updatedAt, order: .reverse) private var resumes: [Resume]
    @Query(filter: #Predicate<ResumeSnapshot> { $0.reasonRaw == "exported" }) private var exports: [ResumeSnapshot]
    @State private var isSettingUpClaude = false

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
        Group {
            if summary.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        quickActions
                        GettingStartedCard(steps: gettingStarted(summary), onShowMe: showMe)
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
        .onAppear {
            // First launch with nothing saved yet.
            if summary.isEmpty, !UserDefaults.standard.bool(forKey: Onboarding.welcomeShownKey) {
                Onboarding.shared.showsWelcome = true
            }
        }
        .sheet(isPresented: $isSettingUpClaude) { ClaudeSetupSheet() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start Your Career Profile", systemImage: AppSection.careerProfile.systemImage)
        } description: {
            Text("Add your details once, then reuse them for every resume. Everything stays on this Mac.")
        } actions: {
            ImportMenu()
            Button("Add Personal Information") { open(.personal) }
            Button("Add Experience", action: addExperience)
        }
    }

    private func gettingStarted(_ summary: DashboardSummary) -> GettingStarted {
        GettingStarted(
            hasNameAndEmail: personalInfo.contains { !$0.fullName.isBlank && !$0.email.isBlank },
            hasBackground: experiences.contains { !$0.needsReview } || education.contains { !$0.needsReview },
            needsReview: summary.needsReviewCount,
            hasResume: !resumes.isEmpty,
            hasExported: !exports.isEmpty,
            hasApplication: !applications.isEmpty,
            claudeConnected: ClaudeBridge.shared.isEnabled
        )
    }

    private func showMe(_ step: GettingStarted.Step) {
        switch step {
        case .personal: open(.personal)
        case .background: open(.professional)
        case .review: openFirstNeedsReview()
        case .resume: go { navigation.section = .resumes }
        case .export:
            // The Master, or the newest resume: Export is in its toolbar.
            let resume = resumes.first(where: \.isMaster) ?? resumes.first
            go {
                navigation.recordToOpen = resume?.id
                navigation.section = .resumes
            }
        case .application:
            go {
                navigation.startsNewRecord = true
                navigation.section = .applications
            }
        case .claude: isSettingUpClaude = true
        }
    }

    private var quickActions: some View {
        HStack {
            Button(action: addExperience) {
                Label("Add Experience", systemImage: "plus")
            }
            ImportMenu(showsTitle: true)
                .fixedSize()
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
                    HStack {
                        CountRow(count: summary.needsReviewCount) { ReviewBadge() }
                        Button("Review", action: openFirstNeedsReview)
                            .buttonStyle(.link)
                            .help("Open the first record that needs review")
                    }
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

    /// The first record that still needs review, on its own page.
    private func openFirstNeedsReview() {
        let target: (ProfileCategory, AnyHashable, String?)? = if let record = personalInfo.first(where: \.needsReview) {
            (.personal, AnyHashable(record.id), nil)
        } else if let record = experiences.first(where: \.needsReview) {
            (record.kind == .professional ? .professional : .organizational, AnyHashable(record.id), nil)
        } else if let record = education.first(where: \.needsReview) {
            (.education, AnyHashable(record.id), nil)
        } else if let record = projects.first(where: \.needsReview) {
            (.projects, AnyHashable(record.id), nil)
        } else if let record = achievements.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "achievements")
        } else if let record = certifications.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "certifications")
        } else if let record = skills.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "skills")
        } else {
            nil
        }
        guard let (category, id, otherKind) = target else { return }
        go {
            // Personal Information is a single record with no list to pick from.
            navigation.recordToOpen = category == .personal ? nil : id
            navigation.otherKind = otherKind
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
