//
//  ResumeRendererTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import PDFKit
import Testing
@testable import Civa

@MainActor
struct ResumeRendererTests {
    private func sample(entries: Int = 2, bullets: Int = 3) -> ResumeDocument {
        var document = ResumeDocument.blank
        document.header = ResumeHeader(fullName: "Alex Morgan", email: "alex@example.com", location: "Jakarta")
        document.summary = "Builds native apps."
        document.sections[0].entries = (1...entries).map { index in
            ResumeEntry(
                title: "Engineer \(index)", subtitle: "Company \(index)", dates: "2024 – Present",
                bullets: (1...bullets).map { "Result \(index).\($0): shipped the feature to every user on time." }
            )
        }
        document.sections[1].entries = [ResumeEntry(title: "Bachelor of Computer Science", subtitle: "Universitas Indonesia")]
        return document
    }

    private func pdf(_ document: ResumeDocument) throws -> PDFDocument {
        try #require(PDFDocument(data: ResumeRenderer.pdf(for: document)))
    }

    @Test func textReadsInOrderWithSummaryUnlabelled() throws {
        let text = try #require(try pdf(sample()).string)
        let order = ["Alex Morgan", "Builds native apps.", "Experience", "Engineer 1", "Engineer 2", "Education"]
        let positions = try order.map { try #require(text.range(of: $0)?.lowerBound) }
        #expect(positions == positions.sorted())
        #expect(!text.contains("Summary"))
    }

    @Test func emptySectionsAreLeftOut() throws {
        var document = ResumeDocument.blank
        document.header.fullName = "Alex Morgan"
        let text = try #require(try pdf(document).string)
        #expect(!text.contains("Experience"))
        #expect(!text.contains("Projects"))
    }

    @Test func entriesAreNeverSplitAcrossPages() throws {
        let document = try pdf(sample(entries: 8, bullets: 5))
        #expect(document.pageCount > 1)
        for index in 1...8 {
            let pages = (0..<document.pageCount).filter { page in
                (document.page(at: page)?.string ?? "").contains("Result \(index).")
            }
            #expect(pages.count == 1, "Engineer \(index) spans pages \(pages)")
        }
    }

    @Test func usesThePaperSize() throws {
        var document = sample()
        document.format.paper = .letter
        let bounds = try #require(try pdf(document).page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.size == CGSize(width: 612, height: 792))
    }

    @Test func blankResumeIsOnePage() throws {
        #expect(try pdf(.blank).pageCount == 1)
    }
}
