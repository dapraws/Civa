//
//  Resume.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// A resume version. Its content lives in `document`, stored as JSON so snapshots (FR-043)
/// and independent versions are plain copies of one value.
@Model
nonisolated final class Resume: EditableRecord {
    var id = UUID()
    var title: String
    var targetPosition: String
    var jobDescription: String
    var documentData: Data
    /// The base for tailored resumes (FR-040). At most one resume has this; see `makeMaster`.
    var isMaster = false
    var createdAt = Date.now
    var updatedAt = Date.now

    /// Applications this resume was sent with. Deleting the resume unlinks them.
    @Relationship(deleteRule: .nullify, inverse: \JobApplication.resume)
    var applications: [JobApplication] = []

    // ponytail: decodes on every read; fine for resume-sized JSON, cache it if editing ever feels slow.
    var document: ResumeDocument {
        get { (try? JSONDecoder().decode(ResumeDocument.self, from: documentData)) ?? .blank }
        set { documentData = (try? JSONEncoder().encode(newValue)) ?? documentData }
    }

    var displayTitle: String {
        title.isBlank ? String(localized: "New Resume") : title
    }

    func validationErrors() -> [PartialKeyPath<Resume>: String] {
        title.isBlank ? [\.title: String(localized: "Enter a name for this resume.")] : [:]
    }

    init(title: String, targetPosition: String = "", jobDescription: String = "", document: ResumeDocument = .blank) {
        self.title = title
        self.targetPosition = targetPosition
        self.jobDescription = jobDescription
        self.documentData = (try? JSONEncoder().encode(document)) ?? Data()
    }
}

extension Resume {
    /// Makes `resume` the only Master Resume, or clears the Master when nil. The caller saves.
    static func makeMaster(_ resume: Resume?, in context: ModelContext) throws {
        let masters = try context.fetch(FetchDescriptor<Resume>(predicate: #Predicate { $0.isMaster }))
        for master in masters where master !== resume { master.isMaster = false }
        resume?.isMaster = true
    }

    /// A tailored copy of this resume. It's independent: later edits to either don't touch the other (FR-041).
    func tailoredCopy(title: String, targetPosition: String, jobDescription: String) -> Resume {
        Resume(title: title, targetPosition: targetPosition, jobDescription: jobDescription, document: document)
    }
}
