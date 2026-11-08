//
//  GettingStartedTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Testing
@testable import Civa

/// The Getting Started steps tick themselves from what's saved.
@MainActor
struct GettingStartedTests {
    @Test func freshStartHasNothingDone() {
        let steps = GettingStarted()
        #expect(steps.items.map(\.step) == [.personal, .background, .resume, .export, .application, .claude])
        #expect(steps.doneCount == 0)
        #expect(steps.requiredCount == 5)
        #expect(!steps.isComplete)
    }

    @Test func reviewStepShowsOnlyWhileSomethingNeedsReview() {
        #expect(GettingStarted(needsReview: 2).items.contains { $0.step == .review && !$0.isDone })
        #expect(GettingStarted(needsReview: 2).requiredCount == 6)
        #expect(!GettingStarted(needsReview: 0).items.contains { $0.step == .review })
    }

    @Test func claudeIsOptional() {
        let steps = GettingStarted(
            hasNameAndEmail: true, hasBackground: true, hasResume: true, hasExported: true, hasApplication: true,
            claudeConnected: false
        )
        #expect(steps.isComplete)
        #expect(steps.doneCount == 5)
        #expect(steps.items.last?.step == .claude)
        #expect(steps.items.last?.isDone == false)
    }

    @Test func eachStepTicksOnItsOwn() {
        #expect(GettingStarted(hasNameAndEmail: true).doneCount == 1)
        #expect(GettingStarted(hasExported: true).items.first { $0.step == .export }?.isDone == true)
        #expect(GettingStarted(claudeConnected: true).doneCount == 0)
    }
}
