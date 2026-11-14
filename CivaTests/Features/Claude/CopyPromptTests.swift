//
//  CopyPromptTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import Testing
@testable import Civa

struct CopyPromptTests {
    private var resume: ResumeDocument {
        var document = ResumeDocument.blank
        document.header.fullName = "Darrel Prawira"
        document.header.headline = "iOS Engineer · SwiftUI"
        document.header.email = "darrel@example.com"
        document.header.phone = "+62 812 0000 0000"
        document.summary = "Builds iOS apps."
        var experience = ResumeSection(kind: .experience)
        var entry = ResumeEntry()
        entry.title = "iOS Engineer"
        entry.subtitle = "Gojek"
        entry.bullets = ["Rebuilt the payment flow in SwiftUI", "  "]
        experience.entries = [entry]
        document.sections = [experience]
        return document
    }

    @Test func improveBulletsCarriesTheRecordAndNothingPersonal() {
        let prompt = CopyPrompt.improveBullets(role: "iOS Engineer", organization: "Gojek", bullets: ["Responsible for payments", ""])
        #expect(prompt.text.contains("iOS Engineer"))
        #expect(prompt.text.contains("Gojek"))
        #expect(prompt.text.contains("- Responsible for payments"))
        #expect(!prompt.text.contains("- \n"))
        #expect(prompt.text.contains("same language"))
        #expect(prompt.text.contains("2–3"))
        #expect(prompt.includes == ["Role and organization", "1 bullet"])
    }

    @Test func improveBulletsWithNoneAsksForADraft() {
        let prompt = CopyPrompt.improveBullets(role: "Lab Assistant", organization: "Telkom University", bullets: [])
        #expect(prompt.text.contains("no bullets yet"))
        #expect(prompt.includes == ["Role and organization"])
    }

    @Test func summaryLeavesOutContactDetails() {
        let prompt = CopyPrompt.writeSummary(resume)
        #expect(prompt.text.contains("iOS Engineer · SwiftUI"))
        #expect(prompt.text.contains("Rebuilt the payment flow in SwiftUI"))
        #expect(prompt.text.contains("Builds iOS apps."))
        #expect(!prompt.text.contains("darrel@example.com"))
        #expect(!prompt.text.contains("+62"))
        #expect(!prompt.text.contains("Darrel Prawira"))
        #expect(prompt.excludes.contains("Your name, email, phone, location, and links"))
    }

    @Test func tailorCarriesTheJobAndTheResume() {
        let prompt = CopyPrompt.tailor(position: "Senior iOS Engineer", company: "Grab", jobDescription: "Swift, SwiftUI, payments.", resume: resume)
        #expect(prompt.text.contains("Senior iOS Engineer"))
        #expect(prompt.text.contains("Grab"))
        #expect(prompt.text.contains("Swift, SwiftUI, payments."))
        #expect(prompt.text.contains("Rebuilt the payment flow in SwiftUI"))
        #expect(!prompt.text.contains("darrel@example.com"))
        #expect(prompt.text.contains("Never invent"))
    }

    @Test func tailorWithoutAResumeSaysSo() {
        let prompt = CopyPrompt.tailor(position: "iOS Engineer", company: "Grab", jobDescription: "Swift.", resume: nil)
        #expect(prompt.text.contains("no resume"))
        #expect(prompt.includes == ["Position and company", "Job description"])
    }

    /// What the eye hides stays out, and contact details typed into any text are replaced.
    @Test func hiddenTextAndTypedContactDetailsStayOut() {
        var document = resume
        document.summary = "Reach me at darrel@example.com or +62 812 3456 7890, portfolio darrel.dev/work."
        document.header.setShows(.headline, false)
        document.sections[0].entries[0].bullets = ["Shipped app, see https://apps.apple.com/app/id123"]
        let summary = CopyPrompt.writeSummary(document)
        #expect(!summary.text.contains("darrel@example.com"))
        #expect(!summary.text.contains("3456"))
        #expect(!summary.text.contains("apps.apple.com"))
        #expect(!summary.text.contains("iOS Engineer · SwiftUI"))
        #expect(summary.text.contains("[email]"))
        var hidden = document
        hidden.hidesSummary = true
        #expect(!CopyPrompt.writeSummary(hidden).text.contains("Reach me"))
        let bullets = CopyPrompt.improveBullets(role: "iOS Engineer", organization: "Gojek", bullets: ["Mail me: a@b.co"])
        #expect(!bullets.text.contains("a@b.co"))
    }
}

