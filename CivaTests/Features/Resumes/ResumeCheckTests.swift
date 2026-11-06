//
//  ResumeCheckTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct ResumeCheckTests {
    private var complete: ResumeDocument {
        var document = ResumeDocument.blank
        document.header = ResumeHeader(fullName: "Alex Morgan", email: "alex@example.com")
        document.sections[0].entries = [ResumeEntry(title: "iOS Engineer")]
        return document
    }

    @Test func completeResumeHasNoIssues() {
        #expect(ResumeCheck.issues(for: complete, pageCount: 1, unconfirmedSources: []).isEmpty)
    }

    @Test func blankResumeAsksForNameContactAndEntries() {
        #expect(ResumeCheck.issues(for: .blank, pageCount: 1, unconfirmedSources: []).count == 3)
    }

    @Test func flagsUntitledEntriesAndEmptySkills() {
        var document = complete
        document.sections[0].entries.append(ResumeEntry())
        document.sections[3].entries = [ResumeEntry(title: "Languages")]
        #expect(ResumeCheck.issues(for: document, pageCount: 1, unconfirmedSources: []).count == 2)
    }

    @Test func flagsUnconfirmedSourcesAndLongResumes() {
        var document = complete
        let source = UUID()
        document.sections[0].entries[0].sourceID = source
        let issues = ResumeCheck.issues(for: document, pageCount: 3, unconfirmedSources: [source])
        #expect(issues.count == 2)
    }
}
