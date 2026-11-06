//
//  MasterResumeTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import Testing
@testable import Civa

@MainActor
struct MasterResumeTests {
    @Test func onlyOneResumeIsMaster() throws {
        let container = try ModelContainer.civa(inMemory: true)  // keep alive: the context doesn't retain it
        let context = container.mainContext
        let first = Resume(title: "First")
        let second = Resume(title: "Second")
        context.insert(first)
        context.insert(second)

        try Resume.makeMaster(first, in: context)
        try Resume.makeMaster(second, in: context)
        #expect(!first.isMaster)
        #expect(second.isMaster)

        try Resume.makeMaster(nil, in: context)
        #expect(!second.isMaster)
    }

    @Test func tailoredCopyIsIndependent() {
        var document = ResumeDocument.blank
        document.summary = "Original"
        let master = Resume(title: "Master", document: document)
        let copy = master.tailoredCopy(title: "Grab", targetPosition: "iOS Engineer", jobDescription: "Swift")

        document.summary = "Changed"
        master.document = document
        #expect(copy.document.summary == "Original")
        #expect(!copy.isMaster)
        #expect(copy.targetPosition == "iOS Engineer")
    }
}
