//
//  OviTip.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation

/// Where Ovi can notice something (tip engine spec §4.1).
enum OviScreen: Hashable {
    case experienceRecord(UUID)
    case projectRecord(UUID)
    case skills
    case resumeEditor(UUID)
    case applicationRecord(UUID)

    enum Kind: Hashable {
        case experienceRecord, projectRecord, skills, resumeEditor, applicationRecord
    }

    var kind: Kind {
        switch self {
        case .experienceRecord: .experienceRecord
        case .projectRecord: .projectRecord
        case .skills: .skills
        case .resumeEditor: .resumeEditor
        case .applicationRecord: .applicationRecord
        }
    }
}

/// Ovi's starter tips, in priority order (spec §4.2).
enum OviTipID: String, CaseIterable, Codable {
    case fontSize, entryDetails, tailor, numericDates, highSchool, pageCount, actionVerb, bulletCount, addNumber, softSkills, numberLog

    /// Shown at most once, ever.
    var isOnceEver: Bool {
        [.pageCount, .softSkills, .numberLog].contains(self)
    }

    var screens: Set<OviScreen.Kind> {
        switch self {
        case .fontSize, .numericDates, .highSchool, .pageCount: [.resumeEditor]
        case .entryDetails, .numberLog: [.experienceRecord]
        case .tailor: [.applicationRecord]
        case .actionVerb, .bulletCount, .addNumber: [.experienceRecord, .projectRecord, .resumeEditor]
        case .softSkills: [.skills, .resumeEditor]
        }
    }
}

/// What a tip's action button does (spec §4.4).
enum OviAction: Equatable {
    case setFontSize10
    case useShortDates
    case tailorCopy(resumeID: UUID)

    var title: String {
        switch self {
        case .setFontSize10: String(localized: "Change to 10 pt")
        case .useShortDates: String(localized: "Use Mar 2024")
        case .tailorCopy: String(localized: "Tailor a copy")
        }
    }
}

extension OviAction {
    /// The change to the resume, for the actions that make one. Through the resume's own editor,
    /// so Revert undoes it like any edit.
    func apply(to document: inout ResumeDocument) {
        switch self {
        case .setFontSize10: document.format.fontSize = 10
        case .useShortDates: document.format.dateStyle = .short
        case .tailorCopy: break
        }
    }
}

extension OviAction {
    /// Applies the change through the resume's editor, so it shows as an unsaved edit that
    /// Save keeps and Revert undoes.
    func apply(to editor: RecordEditor<Resume>) {
        editor.update { resume in
            var document = resume.document
            apply(to: &document)
            resume.document = document
        }
    }
}

/// A tip that matches the current screen, with its copy filled in (spec §4.3).
struct OviMatch: Equatable {
    let tip: OviTipID
    let title: String
    let body: String
    let source: String
    var action: OviAction?
}
