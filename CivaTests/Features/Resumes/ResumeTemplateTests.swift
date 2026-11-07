//
//  ResumeTemplateTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import PDFKit
import Testing
@testable import Civa

/// Every template stays text-based and single-column: headings and entries read in order, and
/// rules and the proof check add no text (BR-001).
@MainActor
struct ResumeTemplateTests {
    private func document(_ template: ResumeFormat.Template) -> ResumeDocument {
        var document = ResumeDocument(header: ResumeHeader(fullName: "Raka Pratama", email: "raka@example.com"))
        document.summary = "iOS engineer."
        var experience = ResumeSection(kind: .experience)
        experience.entries = [ResumeEntry(
            title: "iOS Engineer", subtitle: "Gojek · Jakarta, Indonesia", dates: "2024 – Present",
            bullets: ["Rebuilt checkout"], location: "Jakarta, Indonesia"
        )]
        var certifications = ResumeSection(kind: .certifications)
        certifications.entries = [ResumeEntry(title: "Azure AI Fundamentals", subtitle: "Microsoft", dates: "2025", proofURL: "https://learn.microsoft.com/cert")]
        document.sections = [experience, certifications]
        document.format.apply(template)
        return document
    }

    private func text(_ document: ResumeDocument) throws -> String {
        try #require(PDFDocument(data: ResumeRenderer.pdf(for: document))?.string)
    }

    @Test(arguments: ResumeFormat.Template.allCases)
    func templatesReadInOrder(_ template: ResumeFormat.Template) throws {
        let text = try text(document(template))
        let headings = template == .classic ? ["Experience", "Certifications"] : ["EXPERIENCE", "CERTIFICATIONS"]
        // Tech sets the name in small capitals; Classic leads with the role, the others with the organization.
        let name = template == .tech ? "RAKA PRATAMA" : "Raka Pratama"
        let entry = template == .classic ? ["iOS Engineer", "Gojek"] : ["Gojek", "iOS Engineer"]
        let order = [name, "iOS engineer.", headings[0]] + entry + ["Rebuilt checkout", headings[1], "Azure AI Fundamentals"]
        let positions = order.map { text.range(of: $0)?.lowerBound }
        #expect(!positions.contains(nil), "\(template): \(text)")
        #expect(positions.compactMap(\.self) == positions.compactMap(\.self).sorted(), "\(template): \(text)")
        #expect(text.contains("Jakarta, Indonesia"))
    }

    @Test func dividersAndProofCheckAddNoText() throws {
        var plain = document(.mit)
        plain.format.showsDividers = false
        plain.format.linksProof = false
        let marked = document(.mit)
        #expect(marked.format.dividers)
        #expect(try text(marked) == text(plain))
    }

    @Test func summaryHeadingIsOptional() throws {
        var document = document(.harvard)
        #expect(try !text(document).contains("SUMMARY"))
        document.format.showsSummaryHeading = true
        let text = try text(document)
        #expect(text.contains("SUMMARY"))
        #expect(text.range(of: "SUMMARY")!.lowerBound < text.range(of: "EXPERIENCE")!.lowerBound)
    }

    @Test func applyingATemplateTakesItsFont() {
        var format = ResumeFormat()
        format.showsDividers = false
        format.apply(.mit)
        #expect(format.font == .timesNewRoman)
        #expect(format.fontSize == 10.5)
        #expect(format.dividers)
        #expect(ResumeFormat().layout == .classic)
        #expect(!ResumeFormat().dividers)
    }

    @Test func organizationDropsTheLocation() {
        #expect(ResumeEntry(subtitle: "Gojek · Jakarta", location: "Jakarta").organization == "Gojek")
        #expect(ResumeEntry(subtitle: "Gojek", location: "Jakarta").organization == "Gojek")
        #expect(ResumeEntry(subtitle: "Gojek · Jakarta").organization == "Gojek · Jakarta")
    }

    @Test func copiesWithoutLocationStillMatch() {
        let new = ResumeEntry(title: "iOS Engineer", subtitle: "Gojek · Jakarta", location: "Jakarta").asSourceCopy
        var old = new
        old.location = nil
        #expect(new.matches(old))
        old.location = "Bandung"
        #expect(!new.matches(old))
    }
}
