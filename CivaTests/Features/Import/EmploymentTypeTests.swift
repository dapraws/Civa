//
//  EmploymentTypeTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import PDFKit
import Testing
@testable import Civa

@MainActor
struct EmploymentTypeTests {
    @Test func findsEnglishAndIndonesianNames() {
        #expect(EmploymentType.find(in: "Full-time") == .fullTime)
        #expect(EmploymentType.find(in: "Magang") == .internship)
        #expect(EmploymentType.find(in: "kontrak") == .contract)
        #expect(EmploymentType.find(in: "Mobile Intern") == nil)
    }

    @Test func importTakesTheTypeOutOfTheCompanyLine() {
        let draft = CVParser.parse("""
        Experience
        iOS Engineer
        Tokopedia · Full-time
        Mar 2024 – Present
        Designer (Magang) — Gojek
        2023 – 2023
        """)
        let jobs = draft.items.filter { $0.category == .experience }
        #expect(jobs.map(\.employmentType) == [.fullTime, .internship])
        #expect(jobs.map(\.subtitle) == ["Tokopedia", "Gojek"])
        #expect(jobs[0].location.isEmpty)
        #expect(jobs[1].title == "Designer")
    }

    @Test func resumesSavedBeforeTheFieldStillOpen() throws {
        let old = #"{"header":{"fullName":"Alex","headline":"","email":"","phone":"","location":"","links":[]},"summary":"","sections":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"experience","entries":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","title":"iOS Engineer","subtitle":"Tokopedia","dates":"","bullets":[]}]}],"format":{"font":"Helvetica Neue","fontSize":10,"margins":"normal","lineSpacing":1.15,"sectionSpacing":10,"accent":"black","paper":"a4"}}"#
        let document = try JSONDecoder().decode(ResumeDocument.self, from: Data(old.utf8))
        #expect(document.sections[0].entries[0].title == "iOS Engineer")
        #expect(document.format.showsEmploymentType == nil)
    }

    @Test func printsTheTypeOnlyWhenTheResumeShowsIt() {
        var document = ResumeDocument.blank
        document.sections[0].entries = [ResumeEntry(title: "iOS Engineer", subtitle: "Tokopedia", employmentType: "Internship")]
        func text() -> String { PDFDocument(data: ResumeRenderer.pdf(for: document))?.string ?? "" }
        #expect(!text().contains("Internship"))
        document.format.showsEmploymentType = true
        #expect(text().contains("Internship"))
    }

    @Test func builderCopiesTheTypeIntoResumes() {
        let job = Experience(kind: .professional, organization: "Tokopedia", role: "iOS Engineer")
        job.employmentType = .contract
        let document = ResumeBuilder.document(from: .init(experiences: [job]))
        #expect(document.sections[0].entries[0].employmentType == "Contract")
    }
}
