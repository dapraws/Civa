//
//  ResumeBuilderTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Testing
@testable import Civa

@MainActor
struct ResumeBuilderTests {
    @Test func copiesHeaderAndMapsExperienceWithSourceLinks() {
        let job = Experience(
            kind: .professional, organization: "Acme", role: "iOS Engineer", location: "Jakarta",
            start: YearMonth(year: 2024, month: 3), isCurrent: true,
            details: "Built onboarding.", impacts: ["Cut drop-off by 18%"],
            customFields: [CustomField(name: "Team Size", value: "6")]
        )
        let document = ResumeBuilder.document(from: .init(
            personalInfo: PersonalInfo(fullName: "Alex Morgan", email: "alex@example.com"),
            experiences: [job]
        ))

        #expect(document.header.fullName == "Alex Morgan")
        #expect(document.sections.map(\.kind) == [.experience])
        let entry = document.sections[0].entries[0]
        #expect(entry.sourceID == job.id)
        #expect(entry.title == "iOS Engineer")
        #expect(entry.subtitle == "Acme · Jakarta")
        #expect(entry.bullets == ["Cut drop-off by 18%"])
        #expect(!entry.bullets.contains("6"))
    }

    @Test func descriptionStandsInWhenThereAreNoImpacts() {
        let project = Project(name: "Civa", details: "A career workspace.")
        let document = ResumeBuilder.document(from: .init(projects: [project]))
        #expect(document.sections[0].entries[0].bullets == ["A career workspace."])
    }

    @Test func skipsRecordsThatNeedReview() {
        let document = ResumeBuilder.document(from: .init(
            personalInfo: PersonalInfo(fullName: "Alex", status: .needsReview),
            experiences: [Experience(kind: .professional, organization: "Globex", role: "Intern", status: .needsReview)],
            skills: [Skill(name: "Figma", status: .needsReview)]
        ))
        #expect(document.header.fullName.isEmpty)
        #expect(document.sections.isEmpty)
    }

    @Test func separatesOrganizationalExperienceAndGroupsSkills() {
        let document = ResumeBuilder.document(from: .init(
            experiences: [Experience(kind: .organizational, organization: "Club", role: "Lead")],
            skills: [
                Skill(name: "SwiftUI", category: "Frameworks"),
                Skill(name: "Swift", category: "Languages"),
                Skill(name: "Kotlin", category: "Languages"),
                Skill(name: "Figma"),
            ]
        ))
        #expect(document.sections.map(\.kind) == [.organizational, .skills])
        let lines = document.sections[1].entries.map { "\($0.title)|\($0.subtitle)" }
        #expect(lines == ["Frameworks|SwiftUI", "Languages|Kotlin, Swift", "|Figma"])
    }
}
