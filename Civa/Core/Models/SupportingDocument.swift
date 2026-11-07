//
//  SupportingDocument.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

nonisolated enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case certificate, projectDocument, portfolio, jobPosting, coverLetter, offerLetter, other

    var id: Self { self }

    var title: String {
        switch self {
        case .certificate: String(localized: "Certificate")
        case .projectDocument: String(localized: "Project Document")
        case .portfolio: String(localized: "Portfolio")
        case .jobPosting: String(localized: "Job Posting")
        case .coverLetter: String(localized: "Cover Letter")
        case .offerLetter: String(localized: "Offer Letter")
        case .other: String(localized: "Other")
        }
    }

    /// The heading over this kind's group in Documents.
    var groupTitle: String {
        switch self {
        case .certificate: String(localized: "Certificates")
        case .projectDocument: String(localized: "Project Documents")
        case .portfolio: String(localized: "Portfolio")
        case .jobPosting: String(localized: "Job Postings")
        case .coverLetter: String(localized: "Cover Letters")
        case .offerLetter: String(localized: "Offer Letters")
        case .other: String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .certificate: "rosette"
        case .projectDocument: "doc.text"
        case .portfolio: "photo.on.rectangle"
        case .jobPosting: "doc.text.magnifyingglass"
        case .coverLetter: "envelope"
        case .offerLetter: "signature"
        case .other: "doc"
        }
    }
}

/// A certificate, project document, or portfolio file kept with the Career Profile (FR-022),
/// or a job posting, cover letter, or offer letter kept with an application.
/// Civa keeps its own copy, stored outside the database, so it works even if the original moves.
/// Documents never change profile records by themselves.
@Model
nonisolated final class SupportingDocument: EditableRecord {
    var id = UUID()
    var name: String
    /// The original file name, which carries the extension Quick Look needs.
    var fileName: String
    var kindRaw: String
    var notes: String
    @Attribute(.externalStorage) var data: Data
    var createdAt = Date.now
    var updatedAt = Date.now

    // At most one is set: the record this document supports, or none for general files.
    var experience: Experience?
    var education: Education?
    var project: Project?
    var achievement: Achievement?
    var certification: Certification?
    var application: JobApplication?

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        name.isBlank ? String(localized: "Untitled Document") : name
    }

    func validationErrors() -> [PartialKeyPath<SupportingDocument>: String] {
        name.isBlank ? [\.name: String(localized: "Enter a name for this document.")] : [:]
    }

    var contentType: UTType? { UTType(filenameExtension: (fileName as NSString).pathExtension) }

    init(name: String, fileName: String, data: Data, kind: DocumentKind = .other, notes: String = "") {
        self.name = name
        self.fileName = fileName
        self.data = data
        self.kindRaw = kind.rawValue
        self.notes = notes
    }
}

extension SupportingDocument {
    /// Files above this size ask before they're added.
    static let largeFileSize = 50 * 1_024 * 1_024

    var linkedRecord: (any DocumentHolder)? {
        experience ?? education ?? project ?? achievement ?? certification ?? application
    }

    /// Links to `record` alone, or to nothing.
    func link(to record: (any DocumentHolder)?) {
        experience = nil
        education = nil
        project = nil
        achievement = nil
        certification = nil
        application = nil
        switch record {
        case let record as Experience: experience = record
        case let record as Education: education = record
        case let record as Project: project = record
        case let record as Achievement: achievement = record
        case let record as Certification: certification = record
        case let record as JobApplication: application = record
        default: break
        }
    }

    /// A readable file for Quick Look and import, written once to the temporary folder.
    func fileURL() -> URL? {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Documents/\(id.uuidString)")
        let url = folder.appending(path: fileName.isEmpty ? "Document" : fileName)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    /// A first guess at the kind, from the file and where it's attached.
    static func guessKind(fileName: String, for record: (any DocumentHolder)?) -> DocumentKind {
        let lower = fileName.lowercased()
        switch record {
        case is Certification: return .certificate
        case is Project: return .projectDocument
        case is JobApplication:
            if ["offer", "penawaran"].contains(where: lower.contains) { return .offerLetter }
            if ["cover", "lamaran"].contains(where: lower.contains) { return .coverLetter }
            return .jobPosting
        default: break
        }
        if ["certificate", "sertifikat", "cert"].contains(where: lower.contains) { return .certificate }
        if UTType(filenameExtension: (fileName as NSString).pathExtension)?.conforms(to: .image) == true { return .portfolio }
        return .other
    }
}

/// A record that documents can be attached to.
nonisolated protocol DocumentHolder: EditableRecord {
    var id: UUID { get }
    var documents: [SupportingDocument] { get }
}

extension JobApplication: DocumentHolder {}

/// A Career Profile record that documents can be attached to.
nonisolated protocol DocumentOwner: ImportableRecord, DocumentHolder {
    /// The record's proof or credential link as typed; empty when there is none.
    var proofLink: String { get }
}

nonisolated extension DocumentOwner {
    /// The link first, since it's what a reader can open; otherwise the oldest attached document.
    var proof: Proof? {
        if let url = URL.webLink(proofLink) { return .link(url) }
        return documents.min { $0.createdAt < $1.createdAt }.map(Proof.document)
    }
}

extension Experience: DocumentOwner {
    var proofLink: String { proofURL }
}
extension Education: DocumentOwner {
    var proofLink: String { proofURL }
}
extension Project: DocumentOwner {
    /// A live project or its code shows it exists.
    var proofLink: String { url.isBlank ? repositoryURL : url }
}
extension Achievement: DocumentOwner {
    var proofLink: String { proofURL }
}
extension Certification: DocumentOwner {
    var proofLink: String { credentialURL }
}

nonisolated extension SupportingDocument {
    /// Documents grouped by kind in the kinds' order, newest first within a kind.
    static func galleryOrder(_ a: SupportingDocument, _ b: SupportingDocument) -> Bool {
        let kinds = DocumentKind.allCases
        let (ka, kb) = (kinds.firstIndex(of: a.kind) ?? kinds.count, kinds.firstIndex(of: b.kind) ?? kinds.count)
        return ka != kb ? ka < kb : a.createdAt > b.createdAt
    }
}
