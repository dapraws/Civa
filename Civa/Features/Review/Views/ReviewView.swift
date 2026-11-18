//
//  ReviewView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import SwiftData
import SwiftUI

/// One place for everything waiting on the user: Claude's suggestions and drafts, and Career
/// Profile records that need review. Each row opens the page where it's decided.
struct ReviewView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(UnsavedChangesGuard.self) private var changes
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }) private var proposals: [ClaudeProposal]
    @Query private var personalInfo: [PersonalInfo]
    @Query private var experiences: [Experience]
    @Query private var education: [Education]
    @Query private var projects: [Project]
    @Query private var achievements: [Achievement]
    @Query private var certifications: [Certification]
    @Query private var skills: [Skill]

    private var inbox: ReviewInbox {
        let records: [any ProfileRecord] = personalInfo + experiences + education + projects + achievements + certifications + skills
        return ReviewInbox(proposals: proposals, records: records)
    }

    var body: some View {
        let inbox = inbox
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(String(localized: "Review"))
                .padding(.horizontal, Space.xl)
                .padding(.top, 20)
                .padding(.bottom, Space.m)
            Rectangle().fill(Color.hairline).frame(height: 1)
            if inbox.count == 0 {
                EmptyStateView(
                    symbol: "checkmark.circle",
                    title: "Nothing to review",
                    message: "Claude's suggestions and records you imported show up here until you decide on them."
                )
                .padding(.horizontal, Space.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Form {
                    if !inbox.suggestions.isEmpty {
                        Section {
                            ForEach(inbox.suggestions) { ClaudeProposalRow(proposal: $0) }
                        } header: {
                            Text("From Claude")
                        } footer: {
                            Text("Nothing changes until you apply a suggestion.")
                        }
                    }
                    if !inbox.records.isEmpty {
                        Section {
                            ForEach(inbox.records) { record in
                                HStack {
                                    Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.title)
                                        Text(record.kindTitle).font(.callout).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Review") { open(record) }.civaButton(.textLink)
                                }
                            }
                        } header: {
                            Text("Records to Confirm")
                        } footer: {
                            Text("Imported records stay out of resumes and away from Claude until you confirm them.")
                        }
                    }
                }
                .civaForm()
            }
        }
        .background(Color.canvas)
    }

    private func open(_ record: ReviewInbox.Record) {
        changes.perform {
            // Personal Information is a single record with no list to pick from.
            navigation.recordToOpen = record.category == .personal ? nil : AnyHashable(record.id)
            navigation.otherKind = record.otherKind
            navigation.profileCategory = record.category
            navigation.section = .careerProfile
        }
    }
}

#Preview {
    ReviewView()
        .previewEnvironment()
}
