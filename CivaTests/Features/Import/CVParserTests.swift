//
//  CVParserTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct CVParserTests {
    private let english = """
    Alex Morgan
    iOS Engineer
    Jakarta | alex@example.com | +62 812 3456 7890 | linkedin.com/in/alexmorgan

    SUMMARY
    iOS engineer building native apps.

    Work Experience
    iOS Engineer — Tokopedia
    Mar 2024 – Present
    • Cut onboarding drop-off by 18%
    • Shipped offline cart sync
    Mobile Intern at Traveloka
    Jun 2023 - Dec 2023
    - Rebuilt the booking summary screen

    Education
    Universitas Indonesia
    Bachelor of Computer Science, 2019 – 2023

    Skills
    Languages: Swift, Kotlin
    Figma, Git

    Interests
    Climbing
    """

    @Test func readsContactDetails() {
        let personal = CVParser.parse(english).personal
        #expect(personal.fullName == "Alex Morgan")
        #expect(personal.headline == "iOS Engineer")
        #expect(personal.email == "alex@example.com")
        #expect(personal.phone == "+62 812 3456 7890")
        #expect(personal.location == "Jakarta")
        #expect(personal.links.map(\.label) == ["LinkedIn"])
    }

    @Test func splitsExperienceIntoEntries() {
        let jobs = CVParser.parse(english).items.filter { $0.category == .experience }
        #expect(jobs.count == 2)
        #expect(jobs[0].title == "iOS Engineer")
        #expect(jobs[0].subtitle == "Tokopedia")
        #expect(jobs[0].start == YearMonth(year: 2024, month: 3))
        #expect(jobs[0].isCurrent)
        #expect(jobs[0].bullets == ["Cut onboarding drop-off by 18%", "Shipped offline cart sync"])
        #expect(jobs[1].title == "Mobile Intern")
        #expect(jobs[1].subtitle == "Traveloka")
        #expect(jobs[1].end == YearMonth(year: 2023, month: 12))
        #expect(jobs.allSatisfy { !$0.needsCheck })
    }

    @Test func putsDegreeAsTitleAndSchoolAsInstitution() {
        let education = CVParser.parse(english).items.filter { $0.category == .education }
        #expect(education.count == 1)
        #expect(education[0].title == "Bachelor of Computer Science")
        #expect(education[0].subtitle == "Universitas Indonesia")
        #expect(education[0].start == YearMonth(year: 2019))
        #expect(education[0].end == YearMonth(year: 2023))
    }

    @Test func listsSkillsWithCategories() {
        let skills = CVParser.parse(english).items.filter { $0.category == .skills }
        #expect(skills.map(\.title) == ["Swift", "Kotlin", "Figma", "Git"])
        #expect(skills.map(\.subtitle) == ["Languages", "Languages", "", ""])
    }

    @Test func keepsWhatItCannotPlace() {
        let unsorted = CVParser.parse(english).unsorted
        #expect(unsorted.contains("iOS engineer building native apps."))
        #expect(unsorted.contains("Climbing"))
    }

    @Test func readsIndonesianHeadingsAndMonths() {
        let draft = CVParser.parse("""
        Budi Santoso
        budi@mail.com
        PENGALAMAN KERJA
        Software Engineer - Gojek
        Agustus 2022 - Sekarang
        PENDIDIKAN
        Institut Teknologi Bandung
        S1 Informatika
        2018 - 2022
        KEAHLIAN
        Swift; Python
        """)
        let job = draft.items.first { $0.category == .experience }
        #expect(job?.title == "Software Engineer")
        #expect(job?.start == YearMonth(year: 2022, month: 8))
        #expect(job?.isCurrent == true)
        let school = draft.items.first { $0.category == .education }
        #expect(school?.subtitle == "Institut Teknologi Bandung")
        #expect(school?.title == "S1 Informatika")
        #expect(draft.items.filter { $0.category == .skills }.map(\.title) == ["Swift", "Python"])
    }

    @Test func parsesDateFormats() {
        #expect(CVParser.dateLine("03/2021 – 12/2022")?.start == YearMonth(year: 2021, month: 3))
        #expect(CVParser.dateLine("Sept 2020 to May 2021")?.end == YearMonth(year: 2021, month: 5))
        #expect(CVParser.dateLine("Okt 2019 - Saat ini")?.isCurrent == true)
        #expect(CVParser.dateLine("AWS Cloud Practitioner (2024)")?.rest == "AWS Cloud Practitioner")
        #expect(CVParser.dateLine("No dates here") == nil)
    }

    @Test func importsCivasOwnPDFExport() throws {
        var document = ResumeDocument.blank
        document.header = ResumeHeader(fullName: "Alex Morgan", headline: "iOS Engineer", email: "alex@example.com", location: "Jakarta")
        document.sections[0].entries = [
            ResumeEntry(title: "iOS Engineer", subtitle: "Tokopedia · Jakarta", dates: "Mar 2024 – Present", bullets: ["Cut drop-off by 18%"]),
        ]
        document.sections[3].entries = [ResumeEntry(title: "Languages", subtitle: "Swift, Kotlin")]
        let url = FileManager.default.temporaryDirectory.appending(path: "civa-roundtrip-\(UUID()).pdf")
        try ResumeRenderer.pdf(for: document).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let draft = CVParser.parse(try CVTextExtractor.text(from: url))
        #expect(draft.personal.fullName == "Alex Morgan")
        #expect(draft.personal.email == "alex@example.com")
        let job = draft.items.first { $0.category == .experience }
        #expect(job?.title == "iOS Engineer")
        #expect(job?.subtitle == "Tokopedia")
        #expect(job?.isCurrent == true)
        #expect(job?.bullets == ["Cut drop-off by 18%"])
        #expect(draft.items.filter { $0.category == .skills }.map(\.title) == ["Swift", "Kotlin"])
    }

    @Test func readsWordFiles() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "civa-cv-\(UUID()).docx")
        let data = try NSAttributedString(string: english).data(
            from: NSRange(location: 0, length: english.utf16.count),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let draft = CVParser.parse(try CVTextExtractor.text(from: url))
        #expect(draft.personal.fullName == "Alex Morgan")
        #expect(draft.items.count { $0.category == .experience } == 2)
    }

    @Test func rejectsUnsupportedAndEmptyFiles() throws {
        let text = FileManager.default.temporaryDirectory.appending(path: "civa-\(UUID()).txt")
        try "hello".write(to: text, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: text) }
        #expect(throws: CVTextExtractor.Failure.unsupported) { try CVTextExtractor.text(from: text) }
    }

    @Test func addsCheckedItemsAsNeedsReviewAndOnlyFillsEmptyPersonalFields() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let person = PersonalInfo(fullName: "Alex M.", email: "")
        let swift = Skill(name: "Swift")
        context.insert(person)
        context.insert(swift)
        try context.save()

        var draft = CVParser.parse(english)
        draft.match(against: [swift.importItem])
        #expect(draft.items.first { $0.title == "Swift" }?.isIncluded == false)

        let source = RecordSource(name: "cv.pdf", date: .now)
        draft.add(to: context, existing: person, records: [swift.id: swift], source: source)
        try context.save()
        #expect(person.fullName == "Alex M.")  // kept
        #expect(person.email == "alex@example.com")  // filled
        #expect(person.needsReview)
        #expect(person.sources.map(\.name) == ["cv.pdf"])
        let experiences = try context.fetch(FetchDescriptor<Experience>())
        #expect(experiences.count == 2)
        #expect(experiences.allSatisfy { $0.needsReview && $0.sources == [source] })
        let skillCount = try context.fetchCount(FetchDescriptor<Skill>())
        #expect(skillCount == 4)  // Swift not added twice
    }
}
