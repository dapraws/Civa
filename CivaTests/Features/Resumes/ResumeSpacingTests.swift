//
//  ResumeSpacingTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import PDFKit
import Testing
@testable import Civa

/// Every spacing control moves the text on the page, not just the numbers in the ribbon.
@MainActor
struct ResumeSpacingTests {
    private func document(_ change: (inout ResumeFormat) -> Void = { _ in }) -> ResumeDocument {
        var document = ResumeDocument(header: ResumeHeader(fullName: "Raka Pratama", email: "raka@example.com"))
        var experience = ResumeSection(kind: .experience)
        experience.entries = [
            ResumeEntry(title: "iOS Engineer", subtitle: "Gojek", dates: "2024 – Present", bullets: ["Rebuilt checkout"]),
            ResumeEntry(title: "Mobile Intern", subtitle: "Tokopedia", dates: "2023", bullets: ["Built a widget"]),
        ]
        var certifications = ResumeSection(kind: .certifications)
        certifications.entries = [ResumeEntry(title: "Azure AI Fundamentals", subtitle: "Microsoft", dates: "2025")]
        document.sections = [experience, certifications]
        change(&document.format)
        return document
    }

    /// Where `text` starts on the first page, from the top and the left.
    private func position(of text: String, in document: ResumeDocument) throws -> CGPoint {
        let pdf = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document)))
        let page = try #require(pdf.page(at: 0))
        let selection = try #require(pdf.findString(text, withOptions: []).first)
        let bounds = selection.bounds(for: page)
        return CGPoint(x: bounds.minX, y: page.bounds(for: .mediaBox).height - bounds.maxY)
    }

    @Test func sectionSpacingMovesHeadings() throws {
        let tight = try position(of: "Certifications", in: document { $0.sectionSpacing = 4 })
        let roomy = try position(of: "Certifications", in: document { $0.sectionSpacing = 20 })
        // Two headings sit above it: Experience and Certifications itself.
        #expect(roomy.y - tight.y > 30, "\(tight.y) → \(roomy.y)")
    }

    @Test func entrySpacingMovesLaterEntries() throws {
        let tight = try position(of: "Mobile Intern", in: document { $0.entrySpacing = 0 })
        let roomy = try position(of: "Mobile Intern", in: document { $0.entrySpacing = 12 })
        #expect(abs(roomy.y - tight.y - 12) < 1, "\(tight.y) → \(roomy.y)")
    }

    @Test func lineSpacingMovesLines() throws {
        let single = try position(of: "Azure", in: document { $0.lineSpacing = 1 })
        let roomy = try position(of: "Azure", in: document { $0.lineSpacing = 1.3 })
        #expect(roomy.y > single.y + 5)
    }

    @Test func sideMarginsMoveTextSideways() throws {
        let normal = try position(of: "Raka", in: document())
        let wide = try position(of: "Raka", in: document { $0.sideMargins = .wide })
        #expect(abs(wide.x - normal.x - 18) < 1)
        // Top and bottom stay where they were.
        #expect(abs(wide.y - normal.y) < 1)
    }

    @Test func noSpaceAboveTheFirstLineOfAPage() throws {
        let plain = try position(of: "Raka", in: document())
        let roomy = try position(of: "Raka", in: document { $0.sectionSpacing = 24 })
        #expect(abs(plain.y - roomy.y) < 1)
    }

    @Test func entryGuidesShowOnlyInThePreview() throws {
        let document = document { $0.entrySpacing = 8 }
        let preview = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document, guides: [.entrySpacing, .lineSpacing]))?.string)
        #expect(preview.contains("8 pt"))
        #expect(preview.contains("1.15×"))
        let exported = PDFDocument(data: ResumeRenderer.pdf(for: document))?.string ?? ""
        #expect(!exported.contains(" pt"), "\(exported)")
    }
}

/// Leadership and volunteer roles get their own resume sections.
@MainActor
struct OrganizationalSectionTests {
    @Test func organizationalRecordsSplitByType() {
        func record(_ role: String, _ type: OrganizationType?) -> Experience {
            let experience = Experience(kind: .organizational, organization: "Org", role: role)
            experience.organizationType = type
            return experience
        }
        let document = ResumeBuilder.document(from: .init(experiences: [
            record("Volunteer Tutor", .volunteer), record("Club Member", nil),
            record("President", .leadership), record("Lab Assistant", .assistant),
        ]))
        #expect(document.sections.map(\.title) == ["Leadership Experience", "Organizational Experience", "Volunteer Experience"])
        #expect(document.sections.map { $0.entries.map(\.title).sorted() } == [["President"], ["Club Member", "Lab Assistant"], ["Volunteer Tutor"]])
    }

    @Test func oneTypeOnlyGetsOneSection() {
        let experience = Experience(kind: .organizational, organization: "Red Cross", role: "Volunteer")
        experience.organizationType = .volunteer
        let document = ResumeBuilder.document(from: .init(experiences: [experience]))
        #expect(document.sections.map(\.title) == ["Volunteer Experience"])
    }
}
