//
//  LinkedInPDFTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import Foundation
import PDFKit
import Testing
@testable import Civa

@MainActor
struct LinkedInPDFTests {
    /// Text drawn where LinkedIn's "Save to PDF" puts it, at its font sizes. Made-up person.
    private func linkedInPDF() throws -> PDFDocument {
        // (page, x, y from the bottom, size, text)
        let lines: [(Int, CGFloat, CGFloat, CGFloat, String)] = [
            (0, 22, 733, 13, "Contact"),
            (0, 22, 715, 10.5, "Jl. Contoh No. 1"),
            (0, 22, 702, 10.5, "0812345678 (Mobile)"),
            (0, 22, 690, 10.5, "rina@example.com"),
            (0, 22, 665, 11, "www.linkedin.com/in/rinawijaya"),
            (0, 22, 651, 11, "(LinkedIn)"),
            (0, 22, 637, 11, "rina-"),
            (0, 22, 624, 11, "portfolio.framer.app"),
            (0, 22, 611, 11, "(Personal)"),
            (0, 22, 549, 13, "Top Skills"),
            (0, 22, 531, 10.5, "Figma"),
            (0, 22, 513, 10.5, "User Research"),
            (0, 22, 460, 13, "Languages"),
            (0, 22, 441, 10.5, "Bahasa Inggris (Full Professional)"),
            (0, 22, 358, 13, "Certifications"),
            (0, 22, 339, 10.5, "Google UX Design"),
            (0, 22, 327, 10.5, "Certificate"),
            (0, 22, 196, 13, "Honors-Awards"),
            (0, 22, 177, 10.5, "Finalist (2nd Place) | 2023 Hackathon"),
            (0, 22, 164, 10.5, "Jakarta"),
            (0, 224, 718, 26, "Rina Wijaya"),
            (0, 224, 701, 12, "Product Designer | Design Systems |"),
            (0, 224, 687, 12, "Mentor"),
            (0, 224, 672, 12, "Bandung, West Java, Indonesia"),
            (0, 224, 633, 15.75, "Summary"),
            (0, 224, 608, 12, "Designer focused on fintech."),
            (0, 224, 500, 15.75, "Experience"),
            (0, 224, 470, 12, "Tokopedia"),
            (0, 224, 454, 11.5, "Senior Product Designer"),
            (0, 224, 440, 10.5, "January 2023 - Present (2 years 11 months)"),
            (0, 224, 425, 10.5, "Jakarta, Indonesia"),
            (0, 224, 404, 10.5, "I lead the checkout redesign and the design system used by forty"),
            (0, 224, 386, 10.5, "designers across end-to-"),
            (0, 224, 368, 10.5, "end flows."),
            (0, 224, 332, 10.5, "1. Lifted conversion by 9%"),
            (0, 224, 314, 10.5, "- Cut support tickets by a third"),
            (0, 224, 47, 12, "Gojek"),
            (0, 224, 31, 11.5, "Product Designer"),
            (0, 384, 11, 9, "Page 1 of 2"),
            (1, 224, 735, 10.5, "August 2020 - December 2022 (2 years 5 months)"),
            (1, 224, 720, 10.5, "Jakarta"),
            (1, 224, 699, 10.5, "Designed GoPay onboarding."),
            (1, 224, 159, 15.75, "Education"),
            (1, 224, 134, 12, "Institut Teknologi Bandung"),
            (1, 224, 117, 10.5, "Bachelor's degree, Visual Communication Design · (August"),
            (1, 224, 100, 10.5, "2016 - July 2020)"),
            (1, 384, 11, 9, "Page 2 of 2"),
        ]
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try #require(CGDataConsumer(data: data))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        for page in 0...1 {
            context.beginPDFPage(nil)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            for line in lines where line.0 == page {
                NSAttributedString(string: line.4, attributes: [.font: NSFont(name: "Helvetica", size: line.3)!])
                    .draw(at: CGPoint(x: line.1, y: line.2))
            }
            context.endPDFPage()
        }
        context.closePDF()
        NSGraphicsContext.current = nil
        return try #require(PDFDocument(data: data as Data))
    }

    @Test func recognisesLinkedInsLayoutOnly() throws {
        #expect(LinkedInPDF.isLinkedIn(LinkedInPDF.lines(of: try linkedInPDF())))
        let resume = try #require(PDFDocument(data: ResumeRenderer.pdf(for: .blank)))
        #expect(!LinkedInPDF.isLinkedIn(LinkedInPDF.lines(of: resume)))
    }

    @Test func readsTheMainColumn() throws {
        let draft = LinkedInPDF.draft(from: LinkedInPDF.lines(of: try linkedInPDF()))
        #expect(draft.personal.fullName == "Rina Wijaya")
        #expect(draft.personal.headline == "Product Designer | Design Systems | Mentor")
        #expect(draft.personal.location == "Bandung, West Java, Indonesia")

        let jobs = draft.items.filter { $0.category == .experience }
        #expect(jobs.map(\.title) == ["Senior Product Designer", "Product Designer"])
        #expect(jobs.map(\.subtitle) == ["Tokopedia", "Gojek"])
        #expect(jobs[0].isCurrent)
        #expect(jobs[0].location == "Jakarta, Indonesia")
        #expect(jobs[0].bullets == [
            "I lead the checkout redesign and the design system used by forty designers across end-to-end flows.",
            "Lifted conversion by 9%",
            "Cut support tickets by a third",
        ])
        // The second job's dates sit on the next page.
        #expect(jobs[1].start == YearMonth(year: 2020, month: 8))
        #expect(jobs[1].end == YearMonth(year: 2022, month: 12))
        #expect(jobs[1].bullets == ["Designed GoPay onboarding."])

        let school = try #require(draft.items.first { $0.category == .education })
        #expect(school.subtitle == "Institut Teknologi Bandung")
        #expect(school.title == "Bachelor's degree, Visual Communication Design")
        #expect(school.start == YearMonth(year: 2016, month: 8))
        #expect(school.end == YearMonth(year: 2020, month: 7))
        #expect(draft.unsorted.first == "Designer focused on fintech.")
    }

    @Test func readsTheSidebar() throws {
        let draft = LinkedInPDF.draft(from: LinkedInPDF.lines(of: try linkedInPDF()))
        #expect(draft.personal.email == "rina@example.com")
        #expect(draft.personal.phone == "0812345678")
        #expect(draft.personal.links.map(\.url) == ["www.linkedin.com/in/rinawijaya", "rina-portfolio.framer.app"])
        #expect(draft.personal.links.map(\.label) == ["LinkedIn", "Website"])
        #expect(draft.items.filter { $0.category == .skills }.map(\.title) == ["Figma", "User Research", "Bahasa Inggris"])
        #expect(draft.items.first { $0.category == .certifications }?.title == "Google UX Design Certificate")
        let award = try #require(draft.items.first { $0.category == .achievements })
        #expect(award.title == "Finalist (2nd Place)")
        #expect(award.subtitle == "Hackathon Jakarta")
        #expect(award.start == YearMonth(year: 2023))
        #expect(draft.unsorted.contains("Jl. Contoh No. 1"))
    }
}
