//
//  JobApplicationTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import Testing
@testable import Civa

@MainActor
struct JobApplicationTests {
    @Test func needsPositionAndCompanyOnly() {
        let errors = JobApplication(company: "", position: "").validationErrors()
        #expect(Set(errors.keys) == [\JobApplication.position, \JobApplication.company])
        #expect(JobApplication(company: "Acme", position: "Intern").validationErrors().isEmpty)
    }

    @Test func filtersByStatus() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        context.insert(JobApplication(company: "Acme", position: "Intern", status: .applied))
        context.insert(JobApplication(company: "Globex", position: "Engineer", status: .offer))
        context.insert(JobApplication(company: "Initech", position: "Analyst", status: .applied))
        try context.save()

        let applied = try context.fetch(FetchDescriptor(predicate: JobApplication.withStatus(.applied)))
        #expect(Set(applied.map(\.company)) == ["Acme", "Initech"])
        #expect(try context.fetchCount(FetchDescriptor(predicate: JobApplication.withStatus(nil))) == 3)
    }
}
