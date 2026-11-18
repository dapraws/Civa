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

    /// One of the versions Claude offers for a change, like "Concise" or "With Numbers".
    /// Text fields use `text`; bullets and impacts use `lines`.
    struct Version: Codable, Hashable {
        var label: String
        var text: String?
        var title: String?
        var subtitle: String?
        var lines: [String]?
    }

    /// `resumeEdit`: entries are matched by their id in the resume. Each change is either one
    /// value or 2–3 options to pick from.
    struct ResumeEdit: Codable, Hashable {
        struct Entry: Codable, Hashable {
            var entryID: UUID
            var title: String?
            var subtitle: String?
            var bullets: [String]?
            var options: [Version]?

            /// The options, or the one suggested value.
            var versions: [Version] {
                options ?? [Version(label: "", title: title, subtitle: subtitle, lines: bullets)]
            }
        }

        /// Which change a pick is for.
        enum Change: Hashable {
            case summary
            case entry(UUID)
        }

        /// An entry Civa built from a Career Profile record when Claude suggested it.
        struct Addition: Codable, Hashable {
            var kind: ResumeSection.Kind
            var entry: ResumeEntry
        }

        var summary: String?
        var summaryOptions: [Version]?
        var entries: [Entry] = []
        /// Entries to add, each to the first section of its kind (made when there's none).
        var additions: [Addition]?
        /// Entries to take out, by id.
        var removals: [UUID]?
        /// Section ids or kinds, first to last. Sections not named follow in their order.
        var sectionOrder: [String]?
        /// Entry ids, first to last within their sections. Entries not named follow.
        var entryOrder: [UUID]?
        /// Make this resume the Master Resume.
        var makeMaster: Bool?

        /// Changes to what the resume holds or its order, besides wording.
        var hasStructure: Bool {
            additions?.isEmpty == false || removals?.isEmpty == false || sectionOrder?.isEmpty == false
                || entryOrder?.isEmpty == false || makeMaster == true
        }

        var summaryVersions: [Version] {
            summaryOptions ?? summary.map { [Version(label: "", text: $0)] } ?? []
        }

        var hasOptions: Bool {
            summaryOptions != nil || entries.contains { $0.options != nil }
        }

        /// The edit with the picked version of each change. A change with one value needs no
        /// pick; a change with options and no pick is left out (the user kept theirs).
        func resolved(_ picks: [Change: Int]) -> ResumeEdit {
            func pick(_ versions: [Version], _ change: Change) -> Version? {
                if versions.count == 1 { return versions[0] }
                return picks[change].flatMap { versions.indices.contains($0) ? versions[$0] : nil }
            }
            return ResumeEdit(
                summary: pick(summaryVersions, .summary)?.text,
                entries: entries.compactMap { entry in
                    pick(entry.versions, .entry(entry.entryID)).map {
                        Entry(entryID: entry.entryID, title: $0.title, subtitle: $0.subtitle, bullets: $0.lines)
                    }
                },
                additions: additions, removals: removals, sectionOrder: sectionOrder, entryOrder: entryOrder, makeMaster: makeMaster
            )
        }
    }

    /// `recordEdit`: one field, as text or as lines, or 2–3 options to pick from.
    struct RecordEdit: Codable, Hashable {
        enum Field: String, Codable, CaseIterable {
            case impacts, details, summary, headline
            case role, organization, location, recognition, name, institution, degree
            case fieldOfStudy = "field_of_study"
            case thesis, honors, coursework, title, issuer, placement, category

            /// Fields that hold a list of lines rather than one text.
            var isLines: Bool { self == .impacts || self == .coursework }
        }

        var field: Field
        var text: String?
        var lines: [String]?
        var options: [Version]?

        var versions: [Version] {
            options ?? [Version(label: "", text: text, lines: lines)]
        }

        /// The edit with one version picked.
        func resolved(_ index: Int) -> RecordEdit {
            let version = versions[min(max(index, 0), versions.count - 1)]
            return RecordEdit(field: field, text: version.text, lines: version.lines)
        }
    }

    /// `profileImport`: what Claude read, in the import review's terms.
    struct ProfileImport: Codable, Hashable {
        /// The common fields, plus the ones only some categories have.
        struct Record: Codable, Hashable {
            var category: String
            var title: String
            var subtitle: String?
            var location: String?
            var start: String?
            var end: String?
            var current: Bool?
            var bullets: [String]?
            /// Projects: the user's role. Experience: the job title when `title` is the company.
            var role: String?
            /// Achievements and certifications.
            var issuer: String?
            var issued: String?
            var expires: String?
            /// A test score, like TOEFL 573.
            var score: String?
            var url: String?
            var credentialURL: String?
            var credentialID: String?
            /// Education.
            var fieldOfStudy: String?
            var grade: String?
            /// Achievements: "1st Place".
            var placement: String?

            enum CodingKeys: String, CodingKey {
                case category, title, subtitle, location, start, end, current, bullets, role, issuer, issued, expires, score, url
                case credentialURL = "credential_url", credentialID = "credential_id", fieldOfStudy = "field_of_study", grade, placement
            }
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
