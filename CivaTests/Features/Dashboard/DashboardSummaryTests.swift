//
//  DashboardSummaryTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct DashboardSummaryTests {
    private func summary(
        personalInfo: [PersonalInfo] = [],
        experiences: [Experience] = [],
        skills: [Skill] = [],
        applications: [JobApplication] = [],
        recentLimit: Int = 5
    ) -> DashboardSummary {
        DashboardSummary(
            personalInfo: personalInfo,
            experiences: experiences,
            education: [],
            projects: [],
            achievements: [],
            certifications: [],
            skills: skills,
            applications: applications,
            recentLimit: recentLimit
        )
    }

    @Test func emptyStoreIsEmpty() {
        #expect(summary().isEmpty)
        #expect(summary().missingCategories == ProfileCategory.allCases)
    }

    @Test func countsFilledCategoriesByKindAndOtherInformation() {
        let result = summary(
            personalInfo: [PersonalInfo(fullName: "Alex")],
            experiences: [Experience(kind: .organizational, organization: "Club", role: "Lead")],
            skills: [Skill(name: "Swift")]
        )
        #expect(result.filledCategories == [.personal, .organizational, .other])
        #expect(!result.isEmpty)
    }

    @Test func unnamedPersonalInfoDoesNotCount() {
        #expect(summary(personalInfo: [PersonalInfo(fullName: " ")]).filledCategories.isEmpty)
    }

    @Test func countsRecordsNeedingReview() {
        let result = summary(
            experiences: [
                Experience(kind: .professional, organization: "Acme", role: "Intern", status: .needsReview),
                Experience(kind: .professional, organization: "Globex", role: "Engineer"),
            ],
            skills: [Skill(name: "Swift", status: .needsReview)]
        )
        #expect(result.needsReviewCount == 2)
    }

    @Test func recentActivityIsNewestFirstAndLimited() {
        let old = Skill(name: "Old")
        old.updatedAt = .now.addingTimeInterval(-3_600)
        let new = JobApplication(company: "Acme", position: "Intern")
        let middle = Skill(name: "Middle")
        middle.updatedAt = .now.addingTimeInterval(-60)

        let result = summary(skills: [old, middle], applications: [new], recentLimit: 2)
        #expect(result.recentActivity.map(\.title) == ["Intern", "Middle"])
    }

    @Test func countsApplicationsPerStatusInPipelineOrder() {
        let result = summary(applications: [
            JobApplication(company: "A", position: "X", status: .offer),
            JobApplication(company: "B", position: "Y", status: .applied),
            JobApplication(company: "C", position: "Z", status: .applied),
        ])
        #expect(result.applicationTotal == 3)
        #expect(result.applicationCounts.map(\.status) == ApplicationStatus.allCases)
        #expect(result.applicationCounts.first { $0.status == .applied }?.count == 2)
    }
}
