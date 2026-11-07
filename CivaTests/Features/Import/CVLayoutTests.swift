//
//  CVLayoutTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

/// A CV laid out the MIT way: organization and location with the dates, the role underneath,
/// unmarked bullets that wrap, uncommon section names, and one combined closing section.
/// Fictional data shaped like real CVs that failed to import.
struct CVLayoutTests {
    private let text = """
    RAKA PRATAMA
    +62 812 0000 2847 | raka@example.com | https://github.com/raka-sample
    Software engineer with hands- on experience in AI- powered tools.
    Professional Experience
    Acme Labs - Bali, Indonesia Mar 2026 - Present
    iOS Developer
    Developing iOS apps in SwiftUI with a challenge- based method to identify real- world
    problems and iterate solutions, following platform guidelines.
    Shipped two apps to TestFlight.
    PT Contoh Energi - Jakarta, Indonesia Nov 2025 - Feb 2026
    Software Developer
    Built a semantic search system for internal apps.
    Coding Academy led by Big Tech, Startup, & Unicorn Feb 2024 - Jul 2024
    - Remote
    Graduate with Distinction | Mobile Development
    Delivered an IoT tracking app with a partner.
    Education Level
    Kampus University - Bandung, Indonesia Sep 2021 - Feb 2025
    Bachelor of Informatics, 3.79/4.00
    Additional Experience
    Campus Club - Bandung, Indonesia Jan 2025 - Present
    Chapter Lead
    Leading the campus chapter.
    Hack Batch - Remote Feb 2025 - Jul 2025
    Project Manager
    Led the final team project.
    Achievements, Projects, Certificates, and Skills
    Personal Website (2025): Portfolio Site | Built with SwiftUI
    Achievements (2025): Best Pitching | Hack Batch 2025
    Certificate (2024): Cloud Fundamentals | Example Cloud
    Hard Skills: Python, Swift, Kotlin |
    Firebase, Git
    Soft Skills : Problem Solving, Human-
    Centered Design
    """

    private var items: [ImportItem] { CVParser.parse(text).items }

    private func items(_ category: ImportCategory) -> [ImportItem] {
        items.filter { $0.category == category }
    }

    @Test func uncommonHeadingsSortIntoTheirCategories() {
        #expect(items(.experience).count == 3)
        #expect(items(.education).count == 1)
        #expect(items(.organizational).map(\.title) == ["Chapter Lead", "Project Manager"])
    }

    @Test func organizationFirstEntriesReadTheRoleUnderneath() throws {
        let first = try #require(items(.experience).first)
        #expect(first.title == "iOS Developer")
        #expect(first.subtitle == "Acme Labs")
        #expect(first.location == "Bali, Indonesia")
        #expect(first.isCurrent)
        let academy = try #require(items(.experience).last)
        #expect(academy.location == "Remote")
        #expect(academy.subtitle == "Coding Academy led by Big Tech, Startup, & Unicorn")
        let school = try #require(items(.education).first)
        #expect(school.subtitle == "Kampus University")
        #expect(school.title.hasPrefix("Bachelor of Informatics"))
    }

    @Test func wrappedBulletsJoinAndHyphensClose() throws {
        let first = try #require(items(.experience).first)
        #expect(first.bullets.count == 2, "\(first.bullets)")
        #expect(first.bullets[0].contains("real-world problems"))
        #expect(first.bullets[0].contains("challenge-based"))
        #expect(CVParser.parse(text).personal.headline.isEmpty || !CVParser.parse(text).personal.headline.contains("- "))
    }

    @Test func combinedSectionRoutesEachLine() throws {
        #expect(items(.projects).map(\.title) == ["Portfolio Site"])
        let award = try #require(items(.achievements).first)
        #expect(award.title == "Best Pitching")
        #expect(award.subtitle == "Hack Batch 2025")
        #expect(award.start?.year == 2025)
        #expect(items(.certifications).map(\.subtitle) == ["Example Cloud"])
        let skills = items(.skills)
        #expect(skills.map(\.title) == ["Python", "Swift", "Kotlin", "Firebase", "Git", "Problem Solving", "Human-Centered Design"])
        #expect(skills.first?.subtitle == "Hard Skills")
        #expect(skills.last?.subtitle == "Soft Skills")
    }
}
