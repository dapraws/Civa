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
    case certificate, projectDocument, portfolio, other

    var id: Self { self }

    var title: String {
        switch self {
        case .certificate: String(localized: "Certificate")
        case .projectDocument: String(localized: "Project Document")
        case .portfolio: String(localized: "Portfolio")
        case .other: String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .certificate: "rosette"
        case .projectDocument: "doc.text"
        case .portfolio: "photo.on.rectangle"
        case .other: "doc"
        }
    }
}

/// A certificate, project document, or portfolio file kept with the Career Profile (FR-022).
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

    var linkedRecord: (any DocumentOwner)? {
        experience ?? education ?? project ?? achievement ?? certification
    }

    /// Links to `record` alone, or to nothing.
    func link(to record: (any DocumentOwner)?) {
        experience = nil
        education = nil
        project = nil
        achievement = nil
        certification = nil
        switch record {
        case let record as Experience: experience = record
        case let record as Education: education = record
        case let record as Project: project = record
        case let record as Achievement: achievement = record
        case let record as Certification: certification = record
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
    static func guessKind(fileName: String, for record: (any DocumentOwner)?) -> DocumentKind {
        switch record {
        case is Certification: return .certificate
        case is Project: return .projectDocument
        default: break
        }
        let lower = fileName.lowercased()
        if ["certificate", "sertifikat", "cert"].contains(where: lower.contains) { return .certificate }
        if UTType(filenameExtension: (fileName as NSString).pathExtension)?.conforms(to: .image) == true { return .portfolio }
        return .other
    }
}

/// A Career Profile record that documents can be attached to.
nonisolated protocol DocumentOwner: ImportableRecord {
    var documents: [SupportingDocument] { get }
}

extension Experience: DocumentOwner {}
extension Education: DocumentOwner {}
extension Project: DocumentOwner {}
extension Achievement: DocumentOwner {}
extension Certification: DocumentOwner {}
