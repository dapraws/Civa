//
//  SupportingDocumentTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct SupportingDocumentTests {
    @Test func attachesToManyRecords() {
        let document = SupportingDocument(name: "Transcript", fileName: "transcript.pdf", data: Data())
        let certification = Certification(name: "AWS")
        let project = Project(name: "Civa")
        document.attach(to: certification)
        document.attach(to: project)
        document.attach(to: project)
        #expect(document.linkedRecords.map(\.id) == [project.id, certification.id])

        document.detach(from: certification)
        #expect(document.linkedRecords.map(\.id) == [project.id])
        #expect(!document.isLinked(to: certification))
    }

    /// One transcript on two applications shows on both; detaching from one leaves the other.
    @Test func sharedDocumentShowsOnEachRecord() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let grab = JobApplication(company: "Grab", position: "iOS Engineer")
        let gojek = JobApplication(company: "Gojek", position: "iOS Engineer")
        let transcript = SupportingDocument(name: "Transcript", fileName: "transcript.pdf", data: Data("t".utf8))
        context.insert(grab)
        context.insert(gojek)
        context.insert(transcript)
        transcript.attach(to: grab)
        transcript.attach(to: gojek)
        try context.save()
        #expect(grab.documents.map(\.name) == ["Transcript"])
        #expect(gojek.documents.map(\.name) == ["Transcript"])

        transcript.detach(from: grab)
        try context.save()
        #expect(grab.documents.isEmpty)
        #expect(gojek.documents.map(\.name) == ["Transcript"])
        #expect(try context.fetch(FetchDescriptor<SupportingDocument>()).count == 1)
    }

    @Test func deletingARecordKeepsItsDocuments() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        let certification = Certification(name: "AWS")
        let document = SupportingDocument(name: "Cert", fileName: "cert.pdf", data: Data("pdf".utf8))
        context.insert(certification)
        context.insert(document)
        document.attach(to: certification)
        try context.save()
        #expect(certification.documents.map(\.name) == ["Cert"])

        context.delete(certification)
        try context.save()
        let kept = try context.fetch(FetchDescriptor<SupportingDocument>())
        #expect(kept.count == 1)
        #expect(kept[0].linkedRecords.isEmpty)
        #expect(kept[0].data == Data("pdf".utf8))
    }

    @Test func guessesTheKind() {
        #expect(SupportingDocument.guessKind(fileName: "notes.txt", for: Certification(name: "AWS")) == .certificate)
        #expect(SupportingDocument.guessKind(fileName: "spec.pdf", for: Project(name: "Civa")) == .projectDocument)
        #expect(SupportingDocument.guessKind(fileName: "Sertifikat BNSP.pdf", for: nil) == .certificate)
        #expect(SupportingDocument.guessKind(fileName: "shot.png", for: nil) == .portfolio)
        #expect(SupportingDocument.guessKind(fileName: "letter.docx", for: nil) == .other)
    }

    @Test func writesAReadableCopyForPreview() throws {
        let document = SupportingDocument(name: "Letter", fileName: "Letter.txt", data: Data("hello".utf8))
        let url = try #require(document.fileURL())
        #expect(url.lastPathComponent == "Letter.txt")
        #expect(try Data(contentsOf: url) == Data("hello".utf8))
    }

    @Test func readsChosenFiles() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "civa-doc-\(UUID()).pdf")
        try Data("pdf".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let missing = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID()).pdf")
        let result = DocumentFiles.load([file, missing])
        #expect(result.loaded.map(\.data) == [Data("pdf".utf8)])
        #expect(result.failed == [missing.lastPathComponent])
    }

    @Test func galleryGroupsByKindNewestFirst() {
        let oldCert = SupportingDocument(name: "Old", fileName: "a.pdf", data: Data(), kind: .certificate)
        oldCert.createdAt = .distantPast
        let newCert = SupportingDocument(name: "New", fileName: "b.pdf", data: Data(), kind: .certificate)
        let project = SupportingDocument(name: "Spec", fileName: "c.pdf", data: Data(), kind: .projectDocument)
        let other = SupportingDocument(name: "Misc", fileName: "d.pdf", data: Data(), kind: .other)
        let sorted = [other, project, oldCert, newCert].sorted(by: SupportingDocument.galleryOrder)
        #expect(sorted.map(\.name) == ["New", "Old", "Spec", "Misc"])
        #expect(DocumentKind.certificate.groupTitle == "Certificates")
    }
}
