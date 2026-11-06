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
    var createdAt = Date.now
    var updatedAt = Date.now

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
