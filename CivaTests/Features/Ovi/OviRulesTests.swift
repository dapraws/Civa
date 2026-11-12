//
//  OviRulesTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct OviRulesTests {
    // MARK: Helpers

    private func experience(location: String = "Jakarta", start: YearMonth? = YearMonth(year: 2024, month: 3), impacts: [String] = []) -> Experience {
        Experience(kind: .professional, organization: "Gojek", role: "iOS Engineer", location: location, start: start, impacts: impacts)
    }

    private func resume(fontSize: Double = 11, dateStyle: ResumeFormat.DateStyle? = .short, sections: [ResumeSection] = []) -> ResumeDocument {
        var document = ResumeDocument.blank
        document.format.fontSize = fontSize
        document.format.dateStyle = dateStyle
        document.sections = sections
        return document
    }

    private func ids(_ context: OviContext) -> [OviTipID] {
        OviRules.matches(in: context).map(\.tip)
    }

    private func onExperience(_ record: Experience) -> OviContext {
        OviContext(screen: .experienceRecord(record.id), experience: record)
    }

    private func onResume(_ document: ResumeDocument, pages: Int = 1, levels: [UUID: DegreeLevel] = [:], years: Double = 0) -> OviContext {
        OviContext(screen: .resumeEditor(UUID()), resume: document, resumePageCount: pages, educationLevels: levels, yearsOfExperience: years)
    }

    // MARK: Rules

    @Test func fontSizeFires() {
        let match = OviRules.matches(in: onResume(resume(fontSize: 9.5))).first
        #expect(match?.tip == .fontSize)
        #expect(match?.title == "9.5 pt may be hard to read")
        #expect(match?.action == .setFontSize10)
    }

    @Test func fontSizeIgnoresTen() {
        #expect(!ids(onResume(resume(fontSize: 10))).contains(.fontSize))
    }

    @Test func entryDetailsPrefersLocationVariant() {
        let match = OviRules.matches(in: onExperience(experience(location: "", start: YearMonth(year: 2024, month: nil)))).first
        #expect(match?.tip == .entryDetails)
        #expect(match?.body.contains("location") == true)
    }

    @Test func entryDetailsMonthVariant() {
        let match = OviRules.matches(in: onExperience(experience(start: YearMonth(year: 2024, month: nil)))).first
        #expect(match?.body.contains("no month") == true)
    }

    @Test func entryDetailsIgnoresCompleteEntry() {
        #expect(!ids(onExperience(experience())).contains(.entryDetails))
    }

    @Test func tailorFiresOnMaster() {
        let master = Resume(title: "Master")
        master.isMaster = true
        let application = JobApplication(company: "Stripe", position: "iOS")
        application.resume = master
        let match = OviRules.matches(in: OviContext(screen: .applicationRecord(application.id), application: application)).first
        #expect(match?.tip == .tailor)
        #expect(match?.action == .tailorCopy(resumeID: master.id))
    }

    @Test func tailorIgnoresTailoredResume() {
        let application = JobApplication(company: "Stripe", position: "iOS")
        application.resume = Resume(title: "Stripe")
        #expect(ids(OviContext(screen: .applicationRecord(application.id), application: application)).isEmpty)
    }

    @Test func numericDatesFires() {
        #expect(ids(onResume(resume(dateStyle: .numeric))).contains(.numericDates))
        #expect(!ids(onResume(resume(dateStyle: .long))).contains(.numericDates))
    }

    @Test func highSchoolFiresAlongsideUniversity() {
        let school = UUID(), uni = UUID()
        let section = ResumeSection(kind: .education, entries: [ResumeEntry(sourceID: school), ResumeEntry(sourceID: uni)])
        #expect(ids(onResume(resume(sections: [section]), levels: [school: .highSchool, uni: .bachelor])).contains(.highSchool))
        #expect(!ids(onResume(resume(sections: [section]), levels: [school: .highSchool, uni: .highSchool])).contains(.highSchool))
    }

    @Test func pageCountVariants() {
        let short = OviRules.matches(in: onResume(resume(), pages: 2, years: 1)).first { $0.tip == .pageCount }
        let long = OviRules.matches(in: onResume(resume(), pages: 2, years: 4)).first { $0.tip == .pageCount }
        #expect(short?.title == "Two pages now")
        #expect(long?.title == "Two pages is fine")
        #expect(!ids(onResume(resume(), pages: 1)).contains(.pageCount))
    }

    @Test func actionVerbMatchesIndonesian() {
        let match = OviRules.matches(in: onExperience(experience(impacts: ["bertanggung jawab atas rilis aplikasi"]))).first { $0.tip == .actionVerb }
        #expect(match?.body.hasPrefix("\"Bertanggung jawab\"") == true)
    }

    @Test func actionVerbIgnoresStrongVerb() {
        #expect(!ids(onExperience(experience(impacts: ["Built the GoPay flow"]))).contains(.actionVerb))
    }

    @Test func bulletCountFiresAtSix() {
        let six = (1...6).map { "Shipped feature \($0)" }
        #expect(ids(onExperience(experience(impacts: six))).contains(.bulletCount))
        #expect(!ids(onExperience(experience(impacts: Array(six.prefix(5))))).contains(.bulletCount))
    }

    @Test func addNumberFiresWithoutDigits() {
        #expect(ids(onExperience(experience(impacts: ["Built the flow", "Led the team"]))).contains(.addNumber))
        #expect(!ids(onExperience(experience(impacts: ["Built the flow", "Cut wait time by 20%"]))).contains(.addNumber))
        #expect(!ids(onExperience(experience(impacts: ["Built the flow", "  "]))).contains(.addNumber))
    }

    @Test func resumeRulesCheckEveryEntry() {
        let section = ResumeSection(kind: .projects, entries: [
            ResumeEntry(bullets: ["Shipped 3 apps"]),
            ResumeEntry(bullets: ["Helped the team", "Wrote docs"]),
        ])
        let found = ids(onResume(resume(sections: [section])))
        #expect(found.contains(.actionVerb))
        #expect(found.contains(.addNumber))
    }

    @Test func softSkillsFiresOnCategory() {
        let context = OviContext(screen: .skills, skills: [Skill(name: "Leadership", category: "Soft Skills")])
        #expect(ids(context) == [.softSkills])
        #expect(ids(OviContext(screen: .skills, skills: [Skill(name: "Swift", category: "Tools")])).isEmpty)
    }

    @Test func numberLogFiresOnFirstSaveOfCurrentRole() {
        let record = Experience(kind: .professional, organization: "Gojek", role: "iOS", location: "Jakarta", start: YearMonth(year: 2024, month: 3), isCurrent: true)
        var context = onExperience(record)
        context.justSavedNewCurrentExperience = true
        #expect(ids(context).contains(.numberLog))
        context.justSavedNewCurrentExperience = false
        #expect(!ids(context).contains(.numberLog))
    }

    @Test func tipsOnlyAppearOnTheirScreens() {
        // A record-only rule never fires on the skills screen, and vice versa.
        let context = OviContext(screen: .skills, experience: experience(location: ""), skills: [])
        #expect(ids(context).isEmpty)
    }

    // MARK: Order and copy

    @Test func priorityOrder() {
        #expect(ids(onResume(resume(fontSize: 9, dateStyle: .numeric))).prefix(2) == [.fontSize, .numericDates])
    }

    @Test func bodiesFitTheBubble() {
        for match in OviRules.longestVariants {
            #expect(match.title.count <= 40, "\(match.tip) title: \(match.title.count)")
            #expect(match.body.count <= 120, "\(match.tip) body: \(match.body.count)")
        }
        #expect(Set(OviRules.longestVariants.map(\.tip)) == Set(OviTipID.allCases))
    }
}
