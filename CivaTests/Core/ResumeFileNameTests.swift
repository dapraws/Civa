//
//  ResumeFileNameTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import Testing
@testable import Civa

struct ResumeFileNameTests {
    @Test func nameThenTargetPosition() {
        #expect(ResumeFileName.make(fullName: "Darrel Prawira", target: "iOS Engineer", title: "Master Resume") == "Darrel Prawira - iOS Engineer.pdf")
    }

    @Test func fallsBackToResumeThenTitle() {
        #expect(ResumeFileName.make(fullName: "Darrel Prawira", target: "  ", title: "Master Resume") == "Darrel Prawira - Resume.pdf")
        #expect(ResumeFileName.make(fullName: "", target: "iOS Engineer", title: "Grab Application") == "Grab Application.pdf")
        #expect(ResumeFileName.make(fullName: "", target: "", title: "") == "Resume.pdf")
    }

    /// Slashes and colons can't be in a file name on the Mac.
    @Test func dropsCharactersFilesCantHave() {
        #expect(ResumeFileName.make(fullName: "Darrel", target: "iOS/macOS: Engineer", title: "") == "Darrel - iOS-macOS- Engineer.pdf")
    }

    @MainActor @Test func draggedResumeIsARealPDF() throws {
        var document = ResumeDocument.blank
        document.header.fullName = "Darrel Prawira"
        let resume = Resume(title: "Master Resume", targetPosition: "iOS Engineer", document: document)
        let url = try #require(resume.dragFile())
        #expect(url.lastPathComponent == "Darrel Prawira - iOS Engineer.pdf")
        let data = try Data(contentsOf: url)
        #expect(data.starts(with: Data("%PDF".utf8)))
    }
}
