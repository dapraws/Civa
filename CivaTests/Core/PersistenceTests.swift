//
//  PersistenceTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct PersistenceTests {
    @Test func careerProfileSurvivesReopeningTheStore() throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "Civa.store")

        do {
            let container = try ModelContainer.civa(storeURL: storeURL)
            let context = container.mainContext

            let academy = Experience(
                kind: .organizational,
                organization: "Apple Developer Academy",
                role: "iOS Developer",
                start: YearMonth(year: 2025, month: 3),
                customFields: [CustomField(name: "Team Size", value: "5")],
                status: .needsReview
            )
            academy.skills = [Skill(name: "Swift")]
            let award = Achievement(title: "Best Pitching Team")
            award.experience = academy

            context.insert(academy)
            context.insert(award)
            context.insert(Experience(kind: .professional, organization: "Acme", role: "Intern"))
            try context.save()
        }

        let container = try ModelContainer.civa(storeURL: storeURL)
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Experience>()) == 2)

        let needsReview = ReviewStatus.needsReview.rawValue
        let pending = try context.fetch(
            FetchDescriptor<Experience>(predicate: #Predicate { $0.statusRaw == needsReview })
        )
        #expect(pending.count == 1)

        let academy = try #require(pending.first)
        #expect(academy.kind == .organizational)
        #expect(academy.status == .needsReview)
        #expect(academy.start == YearMonth(year: 2025, month: 3))
        #expect(academy.end == nil)
        #expect(academy.customFields.map(\.value) == ["5"])
        #expect(academy.skills.map(\.name) == ["Swift"])
        #expect(academy.skills.first?.experiences.count == 1)
        #expect(academy.achievements.map(\.title) == ["Best Pitching Team"])
    }
}
