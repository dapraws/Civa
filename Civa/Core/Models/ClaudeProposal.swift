//
//  ClaudeProposal.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// Something the user asked Claude to do from Civa (FR-072). It waits until Claude picks it up
/// with `get_pending_requests`, which happens when the user asks Claude in Claude Desktop.
@Model
nonisolated final class ClaudeRequest {
    enum Kind: String, Codable {
        /// Rewrite a resume's wording for an application's job.
        case tailorResume
        case writeSummary
        /// Better impact lines for one experience or project.
        case improveBullets
        /// A new resume for an application, from the Career Profile.
        case draftResume
    }

    enum Status: String, Codable {
        case pending, answered, failed, cancelled
    }

    var id = UUID()
    var createdAt = Date.now
    var kindRaw: String
    /// The resume, experience, project, or application the request is about.
    var targetID: UUID
    var targetTitle: String
    /// The application whose job to tailor to, for `tailorResume`.
    var applicationID: UUID?
    var statusRaw = Status.pending.rawValue
    var answeredAt: Date?
    /// Claude's note when it finished or couldn't.
    var note = ""

    var kind: Kind { Kind(rawValue: kindRaw) ?? .improveBullets }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var title: String {
        switch kind {
        case .tailorResume: String(localized: "Tailor “\(targetTitle)”")
        case .writeSummary: String(localized: "Write a summary for “\(targetTitle)”")
        case .improveBullets: String(localized: "Improve the bullets of “\(targetTitle)”")
        case .draftResume: String(localized: "Draft a resume for “\(targetTitle)”")
        }
    }

    init(kind: Kind, targetID: UUID, targetTitle: String, applicationID: UUID? = nil) {
        self.kindRaw = kind.rawValue
        self.targetID = targetID
        self.targetTitle = targetTitle
        self.applicationID = applicationID
    }
}

/// A change Claude proposes. Nothing changes until the user applies it in Civa (FR-073).
@Model
nonisolated final class ClaudeProposal {
    enum Kind: String, Codable {
        /// New wording for a resume's summary or entries.
        case resumeEdit
        /// A new value for one field of a profile record.
        case recordEdit
        /// A new resume Claude drafted; `targetID` is that resume, marked as a draft until kept.
        case resumeDraft
        /// Records Claude found, for the import review (FR-020).
        case profileImport
    }

    enum Status: String, Codable {
        case pending, applied, dismissed
    }

    /// `resumeEdit`: entries are matched by their id in the resume.
    struct ResumeEdit: Codable, Hashable {
        struct Entry: Codable, Hashable {
            var entryID: UUID
            var title: String?
            var subtitle: String?
            var bullets: [String]?
        }

        var summary: String?
        var entries: [Entry] = []
    }

    /// `recordEdit`: one field, as text or as lines.
    struct RecordEdit: Codable, Hashable {
        enum Field: String, Codable, CaseIterable {
            case impacts, details, summary, headline
        }

        var field: Field
        var text: String?
        var lines: [String]?
    }

    /// `profileImport`: what Claude read, in the import review's terms.
    struct ProfileImport: Codable, Hashable {
        struct Record: Codable, Hashable {
            var category: String
            var title: String
            var subtitle: String?
            var location: String?
            var start: String?
            var end: String?
            var current: Bool?
            var bullets: [String]?
        }

        var source: String
        var records: [Record]
    }

    var id = UUID()
    var createdAt = Date.now
    var kindRaw: String
    var targetID: UUID?
    var targetTitle: String
    /// Raw value of `ClaudeCategory`.
    var categoryRaw: String
    var requestID: UUID?
    /// Claude's explanation of the change.
    var note: String
    /// The change, encoded per kind.
    var payload: Data
    var statusRaw = Status.pending.rawValue
    var decidedAt: Date?

    var kind: Kind { Kind(rawValue: kindRaw) ?? .resumeEdit }
    var category: ClaudeCategory? { ClaudeCategory(rawValue: categoryRaw) }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: payload)
    }

    init<Payload: Encodable>(
        kind: Kind, targetID: UUID?, targetTitle: String, category: ClaudeCategory,
        requestID: UUID?, note: String, payload: Payload
    ) {
        self.kindRaw = kind.rawValue
        self.targetID = targetID
        self.targetTitle = targetTitle
        self.categoryRaw = category.rawValue
        self.requestID = requestID
        self.note = note
        self.payload = (try? JSONEncoder().encode(payload)) ?? Data()
    }
}
