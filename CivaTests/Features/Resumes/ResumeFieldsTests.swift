//
//  ResumeFieldsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import PDFKit
import Testing
@testable import Civa

@MainActor
struct ResumeFieldsTests {
    private let english = Calendar.resume

    private func education() -> ResumeEntry {
        ResumeEntry(
            title: "Bachelor of Informatics", subtitle: "Telkom University", bullets: ["Cum Laude"],
            start: YearMonth(year: 2020, month: 8), end: YearMonth(year: 2024, month: 8),
            grade: "3.79/4.00", thesis: "On-device speech recognition", coursework: ["Data Structures", "Machine Learning"],
            proofURL: "credentials.example.com/diploma"
        )
    }

    private func text(_ document: ResumeDocument) throws -> String {
        try #require(PDFDocument(data: ResumeRenderer.pdf(for: document))?.string)
    }

    private func document(_ entry: ResumeEntry, kind: ResumeSection.Kind = .education) -> ResumeDocument {
        var document = ResumeDocument()
        document.header.fullName = "Alex Morgan"
        document.sections = [ResumeSection(kind: kind, entries: [entry])]
        return document
    }

    @Test func educationPrintsGradeThesisAndCoursework() throws {
        let text = try text(document(education()))
        #expect(text.contains("Bachelor of Informatics, 3.79/4.00"))
        #expect(text.contains("Thesis: On-device speech recognition"))
        #expect(text.contains("Relevant Coursework: Data Structures, Machine Learning"))

        var hidden = document(education())
        hidden.format.showsGrade = false
        #expect(try !self.text(hidden).contains("3.79/4.00"))
    }

    @Test func datesFollowTheResumeStyle() {
        let entry = education()
        #expect(entry.datesText(.short, calendar: english) == "Aug 2020 – Aug 2024")
        #expect(entry.datesText(.long, calendar: english) == "August 2020 – August 2024")
        #expect(entry.datesText(.numeric, calendar: english) == "08/2020 – 08/2024")

        let typed = ResumeEntry(title: "Intern", dates: "Summer 2023")
        #expect(typed.datesText(.long) == "Summer 2023")
    }

    @Test func workArrangementShowsOnlyWhenTurnedOn() throws {
        let job = ResumeEntry(title: "iOS Engineer", subtitle: "Gojek", workArrangement: "Hybrid")
        #expect(try !text(document(job, kind: .experience)).contains("Hybrid"))
        var shown = document(job, kind: .experience)
        shown.format.showsWorkArrangement = true
        #expect(try text(shown).contains("Hybrid"))
    }

    @Test func chosenHeadingPrints() throws {
        var resume = document(ResumeEntry(title: "iOS Engineer"), kind: .experience)
        resume.sections[0].heading = "Professional Experience"
        #expect(try text(resume).contains("Professional Experience"))
        #expect(ResumeSection.Kind.allCases.allSatisfy { !$0.headingOptions.isEmpty })
    }

    @Test func proofLinkCoversTheTitleLine() throws {
        let pdf = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document(education()))))
        let page = try #require(pdf.page(at: 0))
        let links = page.annotations.filter { $0.url != nil }
        let link = try #require(links.first)
        #expect(link.url?.host() == "credentials.example.com")
        // The entry is near the top of the page; PDF space counts up from the bottom.
        let pageHeight = page.bounds(for: .mediaBox).height
        #expect(link.bounds.minY > pageHeight * 0.7)

        var off = document(education())
        off.format.linksProof = false
        let unlinked = try #require(PDFDocument(data: ResumeRenderer.pdf(for: off))?.page(at: 0))
        #expect(unlinked.annotations.allSatisfy { $0.url == nil })
    }

    @Test func oldResumesStillDecode() throws {
        let old = #"{"header":{"fullName":"Alex","headline":"","email":"","phone":"","location":"","links":[]},"summary":"","sections":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"education","entries":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","title":"BSc","subtitle":"UI","dates":"2019 – 2023","bullets":[]}]}],"format":{"font":"Helvetica Neue","fontSize":10,"margins":"normal","lineSpacing":1.15,"sectionSpacing":10,"accent":"black","paper":"a4"}}"#
        let document = try JSONDecoder().decode(ResumeDocument.self, from: Data(old.utf8))
        let entry = try #require(document.sections.first?.entries.first)
        #expect(entry.datesText(.long) == "2019 – 2023")
        #expect(document.sections[0].title == "Education")
    }

    @Test func profileGradeChangeIsSuggested() throws {
        let profile = Education(institution: "Telkom University", degree: "Bachelor of Informatics")
        profile.gradeValue = 3.7
        var resume = ResumeBuilder.document(from: .init(education: [profile]))
        #expect(resume.sections[0].entries[0].grade == "3.70/4.00")

        profile.gradeValue = 3.79
        let source = ProfileSource(person: nil, records: [profile])
        let suggestions = SuggestedChanges.suggestions(for: resume, from: source)
        #expect(suggestions.first?.changes.map(\.new) == ["3.79/4.00"])
        SuggestedChanges.apply(try #require(suggestions.first), to: &resume, from: source)
        #expect(resume.sections[0].entries[0].grade == "3.79/4.00")
    }
}
