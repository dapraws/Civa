//
//  ValidationTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Testing
@testable import Civa

struct ValidationTests {
    @Test func experienceNeedsRoleAndOrganization() {
        let errors = Experience(kind: .professional, organization: " ", role: "").validationErrors()
        #expect(Set(errors.keys) == [\Experience.role, \Experience.organization])
    }

    @Test func endDateCannotPrecedeStartDate() {
        let reversed = Experience(
            kind: .professional,
            organization: "Acme",
            role: "Intern",
            start: YearMonth(year: 2024, month: 5),
            end: YearMonth(year: 2024, month: 2)
        )
        #expect(reversed.validationErrors()[\Experience.end] != nil)

        reversed.isCurrent = true
        #expect(reversed.validationErrors().isEmpty)
    }

    @Test func certificationCannotExpireBeforeIssue() {
        let certification = Certification(
            name: "AWS",
            issued: YearMonth(year: 2025),
            expires: YearMonth(year: 2024)
        )
        #expect(certification.validationErrors()[\Certification.expires] != nil)
    }

    @Test func personalEmailMustLookLikeAnEmail() {
        #expect(PersonalInfo(fullName: "Alex", email: "alex").validationErrors()[\PersonalInfo.email] != nil)
        #expect(PersonalInfo(fullName: "Alex", email: "").validationErrors().isEmpty)
    }

    @Test func untitledRecordsGetAPlaceholderTitle() {
        #expect(Project(name: "").displayTitle == "New Project")
        #expect(Experience(kind: .professional, organization: "Acme", role: "").displayTitle == "Acme")
    }

    /// Generic code (lists, the dashboard) must see a profile record's review status.
    @Test func needsReviewDispatchesThroughGenerics() {
        func needsReview<M: EditableRecord>(_ record: M) -> Bool { record.needsReview }
        #expect(needsReview(Skill(name: "Swift", status: .needsReview)))
        #expect(!needsReview(Skill(name: "Swift")))
    }
}
