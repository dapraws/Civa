//
//  ProfileFieldsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct ProfileFieldsTests {
    private let english = Locale(identifier: "en_US")

    @Test func readsGradesTypedAsText() throws {
        let gpa = try #require(Grade.parse("3.86 / 4.00"))
        #expect(gpa.grade == Grade(value: 3.86, scale: 4))
        #expect(gpa.label == nil)
        let ipk = try #require(Grade.parse("IPK 3,5 dari 4"))
        #expect(ipk.grade == Grade(value: 3.5, scale: 4))
        #expect(ipk.label == .ipk)
        #expect(Grade.parse("91.4 out of 100")?.grade == Grade(value: 91.4, scale: 100))
        #expect(Grade.parse("Score: 88")?.grade == Grade(value: 88, scale: 100))
        #expect(Grade.parse("3.7")?.grade == Grade(value: 3.7, scale: 4))
    }

    @Test func leavesUnreadableGradesAlone() {
        #expect(Grade.parse("Cum Laude") == nil)
        #expect(Grade.parse("7") == nil)  // out of 10? out of 100? Don't guess.
        #expect(Grade.parse("4.5 / 4") == nil)
        #expect(Grade.parse("") == nil)
    }

    @Test func formatsSmallScalesWithTwoDecimals() {
        #expect(Grade(value: 3.8, scale: 4).formatted(locale: english) == "3.80 / 4.00")
        #expect(Grade(value: 91.4, scale: 100).formatted(locale: english) == "91.4 / 100")
        #expect(Grade(value: 8, scale: 10).formatted(locale: english) == "8 / 10")
    }

    @Test func convertsATextGradeOnce() {
        let education = Education(institution: "Telkom University", grade: "IPK 3.79 / 4.00")
        #expect(education.convertTextGrade())
        #expect(education.gradeValue == 3.79)
        #expect(education.gradeScale == 4)
        #expect(education.gradeLabel == .ipk)
        #expect(education.grade.isEmpty)
        #expect(!education.convertTextGrade())

        let honors = Education(institution: "SMA 3", grade: "With honors")
        #expect(!honors.convertTextGrade())
        #expect(honors.grade == "With honors")
        #expect(honors.gradeText == "With honors")
    }

    @Test func rejectsAGradeAboveTheMaximum() {
        let education = Education(institution: "Telkom University")
        education.gradeValue = 4.2
        #expect(education.validationErrors()[\Education.gradeValue] != nil)
        education.gradeScale = 5
        #expect(education.validationErrors().isEmpty)
        education.gradeScale = 0
        #expect(education.validationErrors()[\Education.gradeScale] != nil)
    }

    @Test func acceptsWebLinksWithOrWithoutTheScheme() {
        #expect(URL.webLink("github.com/raka")?.absoluteString == "https://github.com/raka")
        #expect(URL.webLink("http://example.com/a")?.scheme == "http")
        #expect(URL.webLink("not a link") == nil)
        #expect(URL.webLink("localhost") == nil)
        #expect(URL.webLink("ftp://example.com") == nil)

        let achievement = Achievement(title: "Finalist")
        achievement.proofURL = "nope"
        #expect(achievement.validationErrors()[\Achievement.proofURL] != nil)
    }

    @Test func proofPrefersTheLinkThenADocument() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let project = Project(name: "Kirana")
        context.insert(project)
        #expect(project.proof == nil)

        let document = SupportingDocument(name: "Screenshot", fileName: "kirana.png", data: Data([1]))
        context.insert(document)
        document.attach(to: project)
        guard case .document(let found) = project.proof else { Issue.record("Expected the document"); return }
        #expect(found.id == document.id)

        project.repositoryURL = "github.com/raka/kirana"
        guard case .link(let url) = project.proof else { Issue.record("Expected the link"); return }
        #expect(url.host() == "github.com")

        let skill = Skill(name: "Swift")
        #expect(skill.proof == nil)
    }
}
