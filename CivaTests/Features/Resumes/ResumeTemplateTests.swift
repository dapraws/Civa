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
        let headings = template == .classic || template == .harvard ? ["Experience", "Certifications"] : ["EXPERIENCE", "CERTIFICATIONS"]
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

    @Test func hiddenPartsStayButDontPrint() throws {
        var document = document(.classic)
        let link = ProfileLink(label: "GitHub", url: "github.com/raka")
        document.header.links = [link]
        document.header.phone = "+62 811 0000 0000"
        document.header.setShows(.email, false)
        document.header.setShows(link, false)
        document.hidesSummary = true
        document.sections[0].entries[0].setShows(.dates, false)
        let text = try text(document)
        for hidden in ["raka@example.com", "github.com/raka", "iOS engineer.", "2024"] {
            #expect(!text.contains(hidden), "\(hidden)")
        }
        #expect(text.contains("+62 811 0000 0000"))
        #expect(document.header.email == "raka@example.com")
        document.header.setShows(.email, true)
        document.header.setShows(link, true)
        #expect(document.header.hidden == nil)
    }

    @Test func summaryHeadingIsOptional() throws {
        var document = document(.mit)
        #expect(try !text(document).contains("SUMMARY"))
        document.format.showsSummaryHeading = true
        let text = try text(document)
        #expect(text.contains("SUMMARY"))
        #expect(text.range(of: "SUMMARY")!.lowerBound < text.range(of: "EXPERIENCE")!.lowerBound)
    }

    @Test func harvardFollowsItsWordTemplate() throws {
        var format = ResumeFormat()
        format.margins = .wide
        format.apply(.harvard)
        #expect(format.font == .arial && format.fontSize == 11 && format.margins == .narrow && !format.dividers)
        var document = document(.harvard)
        document.header.phone = "+62 811 0000 0000"
        let text = try text(document)
        #expect(text.contains("raka@example.com • +62 811 0000 0000"))
        #expect(text.contains("Experience") && !text.contains("EXPERIENCE"))
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

    @Test func guidesAppearOnlyInThePreview() throws {
        let document = document(.classic)
        let exported = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document)))
        let preview = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document, guides: Set(ResumeRenderer.Guide.allCases))))
        #expect(exported.pageCount == preview.pageCount)
        #expect(!(exported.string ?? "").contains("0.75 in"))
        let text = try #require(preview.string)
        #expect(text.contains("Top 0.75 in"))
        #expect(text.contains("10 pt"))
        #expect(text.contains("1.15×"))
    }
    /// A long title wraps before the date; the date stays on the title's first line.
    @Test(arguments: ResumeFormat.Template.allCases)
    func longTitlesWrapBeforeTheDate(_ template: ResumeFormat.Template) throws {
        var document = ResumeDocument(header: ResumeHeader(fullName: "Garuda Arrasyid"))
        var projects = ResumeSection(kind: .projects)
        projects.entries = [ResumeEntry(
            title: "Production of Exopolysaccharide by Lactiplantibacillus pentosus FT3 with Varying Nitrogen Sources and NaCl Concentration",
            subtitle: "Undergraduate Thesis", dates: "Apr 2026"
        )]
        document.sections = [projects]
        document.format.apply(template)
        let pdf = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document)))
        let page = try #require(pdf.page(at: 0))
        let title = try #require(pdf.findString("Production", withOptions: []).first).bounds(for: page)
        let date = try #require(pdf.findString("Apr 2026", withOptions: []).first).bounds(for: page)
        #expect(abs(title.midY - date.midY) < 2, "\(template): the date left the title's first line")
        let overlap = page.selection(for: date.insetBy(dx: -3, dy: 1))?.string ?? ""
        #expect(overlap.trimmingCharacters(in: .whitespacesAndNewlines) == "Apr 2026", "\(template): \(overlap)")
    }

    /// A long link that wraps still opens in full: every line it takes is a link to the whole URL.
    @Test func headerLinksOpenTheWholeURL() throws {
        let url = "https://www.linkedin.com/in/muhammad-garuda-arrasyid-309526439"
        var document = ResumeDocument(header: ResumeHeader(
            fullName: "Muhammad Garuda Arrasyid", email: "garuda.raka@example.com", phone: "+6285100000000",
            location: "Jakarta, Indonesia", links: [ProfileLink(label: "LinkedIn", url: url)]
        ))
        document.format.apply(.classic)
        let pdf = try #require(PDFDocument(data: ResumeRenderer.pdf(for: document)))
        let page = try #require(pdf.page(at: 0))
        let text = try #require(pdf.string)
        #expect(text.contains("linkedin.com/in/muhammad-garuda-"))
        #expect(!text.contains("https://www."))
        let links = page.annotations.filter { $0.url?.absoluteString == url }
        #expect(!links.isEmpty)
        let tail = try #require(pdf.findString("309526439", withOptions: []).first).bounds(for: page)
        #expect(links.contains { $0.bounds.insetBy(dx: -1, dy: -1).contains(CGPoint(x: tail.midX, y: tail.midY)) })
        #expect(page.annotations.contains { $0.url?.absoluteString == "mailto:garuda.raka@example.com" })
    }
}
