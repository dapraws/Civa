//
//  JobApplicationTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
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

    @Test func deletingResumeUnlinksApplications() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let resume = Resume(title: "iOS Resume")
        let application = JobApplication(company: "Acme", position: "Intern")
        context.insert(resume)
        context.insert(application)
        application.resume = resume
        try context.save()
        #expect(resume.applications.map(\.company) == ["Acme"])

        context.delete(resume)
        try context.save()
        #expect(application.resume == nil)
        #expect(try context.fetchCount(FetchDescriptor<JobApplication>()) == 1)
    }

    @Test func statusesFollowThePipeline() {
        #expect(ApplicationStatus.allCases == [.wishlist, .applied, .assessment, .interview, .offer, .rejected, .withdrawn])
    }

    @Test func rawValuesUnchanged() {
        for raw in ["wishlist", "applied", "interview", "assessment", "offer", "rejected", "withdrawn"] {
            #expect(ApplicationStatus(rawValue: raw)?.rawValue == raw)
        }
    }

    @Test func applicationsSortNotAppliedFirst() {
        func app(_ name: String, applied: String?, created: String) -> JobApplication {
            let a = JobApplication(company: name, position: "Intern")
            a.applicationDate = applied.map { try! Date($0, strategy: .iso8601) }
            a.createdAt = try! Date(created, strategy: .iso8601)
            return a
        }
        let apps = [
            app("Nov01", applied: "2026-11-01T00:00:00Z", created: "2026-10-01T00:00:00Z"),
            app("NilEarlier", applied: nil, created: "2026-10-02T00:00:00Z"),
            app("Nov05", applied: "2026-11-05T00:00:00Z", created: "2026-10-03T00:00:00Z"),
            app("NilLater", applied: nil, created: "2026-10-04T00:00:00Z"),
        ]
        #expect(apps.sorted(by: JobApplication.listOrder).map(\.company) == ["NilLater", "NilEarlier", "Nov05", "Nov01"])
    }
}
