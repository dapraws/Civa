//
//  OviMoreTipsTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import Testing
@testable import Civa

/// The six tips added on 2026-11-14 (research list #4, #30, #9, #12, #8, #34).
@MainActor
struct OviMoreTipsTests {
    private func resume(_ change: (inout ResumeDocument) -> Void = { _ in }) -> ResumeDocument {
        var document = ResumeDocument.blank
        document.format.fontSize = 11
        document.format.dateStyle = .short
        document.header.fullName = "Darrel"
        document.header.email = "darrel@example.com"
        document.header.phone = "+62 812 0000 0000"
        change(&document)
        return document
    }

    private func onResume(_ document: ResumeDocument, years: Double = 0, gap: Int = 0, justExported: Bool = false) -> [OviTipID] {
        var context = OviContext(screen: .resumeEditor(UUID()), resume: document, resumePageCount: 1)
        context.yearsOfExperience = years
        context.largestGapMonths = gap
        context.justExported = justExported
        return OviRules.matches(in: context).map(\.tip)
    }

    // T1

    @Test func selfPraiseInTheSummary() {
        #expect(onResume(resume { $0.summary = "A hard worker and team player." }).contains(.selfPraise))
        #expect(onResume(resume { $0.summary = "Seorang pekerja keras." }).contains(.selfPraise))
        #expect(!onResume(resume { $0.summary = "Built payment flows used by 2M people." }).contains(.selfPraise))
        let match = OviRules.matches(in: OviContext(screen: .resumeEditor(UUID()), resume: resume { $0.summary = "Hard worker." })).first { $0.tip == .selfPraise }
        #expect(match?.body.contains("\"Hard worker\"") == true)
    }

    @Test func selfPraiseInSkills() {
        let context = OviContext(screen: .skills, skills: [Skill(name: "Team Player", category: "Soft Skills"), Skill(name: "Swift")])
        #expect(OviRules.matches(in: context).map(\.tip).contains(.selfPraise))
        var section = ResumeSection(kind: .skills)
        var entry = ResumeEntry()
        entry.title = "Personal"
        entry.subtitle = "Results-oriented, SwiftUI"
        section.entries = [entry]
        #expect(onResume(resume { $0.sections = [section] }).contains(.selfPraise))
    }

    // T2

    @Test func missingEmailOrPhone() {
        #expect(onResume(resume { $0.header.email = "" }).contains(.contactDetails))
        #expect(onResume(resume { $0.header.setShows(.phone, false) }).contains(.contactDetails))
        #expect(!onResume(resume()).contains(.contactDetails))
    }

    // T3

    @Test func gapOfSixMonthsOrMore() {
        #expect(onResume(resume(), gap: 6).contains(.careerGap))
        #expect(!onResume(resume(), gap: 5).contains(.careerGap))
        #expect(OviTipID.careerGap.isOnceEver)
    }

    @Test func largestGapBetweenProfessionalRoles() {
        let now = try! Date("2026-11-15T00:00:00Z", strategy: .iso8601)
        let records = [
            Experience(kind: .professional, organization: "A", role: "R", start: YearMonth(year: 2021, month: 1), end: YearMonth(year: 2022, month: 6)),
            Experience(kind: .professional, organization: "B", role: "R", start: YearMonth(year: 2023, month: 3), end: YearMonth(year: 2024, month: 1)),
            Experience(kind: .professional, organization: "C", role: "R", start: YearMonth(year: 2024, month: 3), isCurrent: true),
            // Clubs and undated records don't count.
            Experience(kind: .organizational, organization: "Club", role: "Lead", start: YearMonth(year: 2010, month: 1), end: YearMonth(year: 2010, month: 2)),
            Experience(kind: .professional, organization: "D", role: "R"),
        ]
        // June 2022 → March 2023 is 9 months; Jan → Mar 2024 is 2.
        #expect(OviContextBuilder.largestGapMonths(records, now: now) == 9)
        // Overlapping roles leave no gap.
        let overlapping = [
            Experience(kind: .professional, organization: "A", role: "R", start: YearMonth(year: 2020, month: 1), end: YearMonth(year: 2024, month: 1)),
            Experience(kind: .professional, organization: "B", role: "R", start: YearMonth(year: 2021, month: 1), end: YearMonth(year: 2022, month: 1)),
            Experience(kind: .professional, organization: "C", role: "R", start: YearMonth(year: 2024, month: 2), isCurrent: true),
        ]
        #expect(OviContextBuilder.largestGapMonths(overlapping, now: now) == 1)
    }

    // T4

    @Test func educationFirstWithExperience() {
        let education = ResumeSection(kind: .education)
        let experience = ResumeSection(kind: .experience)
        #expect(onResume(resume { $0.sections = [education, experience] }, years: 3).contains(.educationFirst))
        #expect(!onResume(resume { $0.sections = [education, experience] }, years: 1).contains(.educationFirst))
        #expect(!onResume(resume { $0.sections = [experience, education] }, years: 5).contains(.educationFirst))
    }

    // T5

    @Test func proofreadAfterTheFirstExport() {
        #expect(onResume(resume(), justExported: true).contains(.proofread))
        #expect(!onResume(resume()).contains(.proofread))
        #expect(OviTipID.proofread.isOnceEver)
    }

    // T6

    @Test func oneResumeForManyJobs() {
        let resume = Resume(title: "iOS Resume")
        let application = JobApplication(company: "Grab", position: "iOS Engineer")
        application.resume = resume
        var context = OviContext(screen: .applicationRecord(application.id), application: application)
        context.applicationsWithSameResumeThisWeek = 5
        let match = OviRules.matches(in: context).first { $0.tip == .sameResume }
        #expect(match?.action == .tailorCopy(resumeID: resume.id))
        context.applicationsWithSameResumeThisWeek = 4
        #expect(!OviRules.matches(in: context).map(\.tip).contains(.sameResume))
        // The Master already has its own tip (tailor).
        resume.isMaster = true
        context.applicationsWithSameResumeThisWeek = 9
        #expect(!OviRules.matches(in: context).map(\.tip).contains(.sameResume))
    }
}
