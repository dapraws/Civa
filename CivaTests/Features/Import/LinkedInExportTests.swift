//
//  LinkedInExportTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct LinkedInExportTests {
    /// Shaped like LinkedIn's export files, including a multi-line quoted description.
    private let export: [String: String] = [
        "Profile.csv": """
        First Name,Last Name,Maiden Name,Address,Birth Date,Headline,Summary,Industry,Zip Code,Geo Location,Twitter Handles,Websites,Instant Messengers
        Alex,Morgan,,,,iOS Engineer,Builds native apps.,Software,,"Jakarta, Indonesia",,"[PORTFOLIO:https://alex.dev,OTHER:https://github.com/alexm]",
        """,
        "Email Addresses.csv": """
        Email Address,Confirmed,Primary,Updated On
        old@example.com,Yes,No,1/1/20
        alex@example.com,Yes,Yes,1/1/24
        """,
        "Positions.csv": """
        Company Name,Title,Description,Location,Started On,Finished On
        Tokopedia,iOS Engineer,"Cut drop-off by 18%
        • Shipped offline sync, with tests","Jakarta, Indonesia",Mar 2024,
        Traveloka,Mobile Intern,,Jakarta,Jun 2023,Dec 2023
        """,
        "Education.csv": """
        School Name,Start Date,End Date,Notes,Degree Name,Activities
        Universitas Indonesia,2019,2023,GPA 3.7,Bachelor of Computer Science,
        """,
        "Certifications.csv": """
        Name,Url,Authority,Started On,Finished On,License Number
        App Development with Swift,,Apple,May 2024,,
        """,
        "Skills.csv": "Name\r\nSwift\r\nSwiftUI\r\n",
        "Languages.csv": "Name,Proficiency\nIndonesian,Native or bilingual proficiency\n",
        "Connections.csv": "First Name,Last Name\nNot,Read\n",
    ]

    private func writeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Basic_LinkedInDataExport_\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, text) in export {
            try text.write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
        }
        return folder
    }

    /// A real ZIP of the folder, made by macOS itself.
    private func zip(_ folder: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appending(path: "export-\(UUID()).zip")
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zipped in
            do { try FileManager.default.copyItem(at: zipped, to: destination) } catch { copyError = error }
        }
        if let error = coordinatorError ?? copyError { throw error }
        return destination
    }

    @Test func readsQuotedFieldsWithCommasAndLineBreaks() {
        let rows = CSVReader.rows("a,\"b, c\",\"line 1\nline 2\",\"say \"\"hi\"\"\"\r\nx,,z")
        #expect(rows == [["a", "b, c", "line 1\nline 2", "say \"hi\""], ["x", "", "z"]])
    }

    @Test func mapsProfileFilesToTheDraft() throws {
        let folder = try writeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let draft = LinkedInExport.draft(from: try LinkedInExport.files(at: folder))

        #expect(draft.personal.fullName == "Alex Morgan")
        #expect(draft.personal.email == "alex@example.com")
        #expect(draft.personal.location == "Jakarta, Indonesia")
        #expect(draft.personal.links.map(\.url) == ["https://alex.dev", "https://github.com/alexm"])

        let jobs = draft.items.filter { $0.category == .experience }
        #expect(jobs.map(\.subtitle) == ["Tokopedia", "Traveloka"])
        #expect(jobs[0].isCurrent)
        #expect(jobs[0].start == YearMonth(year: 2024, month: 3))
        #expect(jobs[0].bullets == ["Cut drop-off by 18%", "Shipped offline sync, with tests"])
        #expect(jobs[1].end == YearMonth(year: 2023, month: 12))

        let school = draft.items.first { $0.category == .education }
        #expect(school?.title == "Bachelor of Computer Science")
        #expect(school?.isCurrent == false)
        #expect(draft.items.first { $0.category == .certifications }?.subtitle == "Apple")
        #expect(draft.items.filter { $0.category == .skills }.map(\.title) == ["Swift", "SwiftUI", "Indonesian"])
    }

    @Test func readsTheZipAndSkipsOtherFiles() throws {
        let folder = try writeFolder()
        let archive = try zip(folder)
        defer {
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.removeItem(at: archive)
        }
        let files = try LinkedInExport.files(at: archive)
        #expect(files["positions.csv"]?.contains("Tokopedia") == true)
        #expect(files["connections.csv"] == nil)
        #expect(LinkedInExport.draft(from: files).personal.fullName == "Alex Morgan")
    }

    @Test func rejectsFilesThatArentExports() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "not-a-zip-\(UUID()).zip")
        try Data("hello".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(throws: ZipReader.Failure.notZip) { try LinkedInExport.files(at: file) }
    }
}
