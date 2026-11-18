//
//  ReviewInboxTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct ReviewInboxTests {
    @Test func listsClaudesSuggestionsThenRecordsAwaitingReview() {
        let suggestion = ClaudeProposal(
            kind: .resumeEdit, targetID: UUID(), targetTitle: "Master Resume", category: .resumes,
            requestID: nil, note: "Thesis first", payload: ClaudeProposal.ResumeEdit(summary: "New")
        )
        let job = Experience(kind: .organizational, organization: "BEM", role: "Treasurer", status: .needsReview)
        let toefl = Certification(name: "TOEFL ITP", status: .needsReview)
        let confirmed = Skill(name: "PCR")
        let pcr = Skill(name: "Plate Count", status: .needsReview)

        let inbox = ReviewInbox(proposals: [suggestion], records: [job, toefl, confirmed, pcr])
        #expect(inbox.count == 4)
        #expect(inbox.suggestions.map(\.id) == [suggestion.id])
        #expect(inbox.records.map(\.title) == ["Treasurer", "TOEFL ITP", "Plate Count"])
        #expect(inbox.records[0].category == .organizational)
        #expect(inbox.records[1].category == .other && inbox.records[1].otherKind == "certifications")
        #expect(inbox.records[2].otherKind == "skills")
    }

    @Test func emptyWhenNothingWaits() {
        #expect(ReviewInbox(proposals: [], records: [Skill(name: "PCR")]).count == 0)
    }
}
