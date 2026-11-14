//
//  AppNavigation.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Observation

/// Where the window is. Lives at the root so pages keep their place when you switch away and back.
@Observable
final class AppNavigation {
    var section: AppSection = .dashboard
    var profileCategory: ProfileCategory = .personal
    /// Set by quick actions: the next record list that appears starts a new record.
    var startsNewRecord = false
    /// Set after creating a record elsewhere (a sheet); the list showing that record type opens it.
    var recordToOpen: AnyHashable?
    /// Which list Other Information shows next ("achievements", "certifications", "skills").
    var otherKind: String?
    /// Which AI Activity tab shows next, such as Requests after a request notice is clicked.
    var aiActivityTab: AIActivityView.Tab?
    /// The record open in an editor, for Ovi to know which screen this is.
    var openRecordID: UUID?
    /// The record whose first save just succeeded (Ovi's `numberLog`).
    var justSavedRecordID: UUID?
    /// The resume just exported, and when, for Ovi's proofread tip; cleared on the next visit.
    var justExportedResumeID: UUID?
    var justExportedAt: Date?
    /// Bumped when the open editor's changes are reverted, so Ovi closes without Happy.
    var revertCount = 0
    /// Ovi's "Tailor a copy": the Resumes page opens the Tailor sheet for this resume.
    var tailorResumeID: UUID?
    /// The application the Tailor sheet starts with.
    var tailorApplicationID: UUID?
    /// Career Profile → Other → Skills is showing.
    var isOnSkills = false
    /// Which status Applications shows next, such as after a Dashboard pipeline cell is clicked.
    var applicationStatusFilter: ApplicationStatus?

    init() {
        #if DEBUG
        // Open on a given page for manual checks: -CivaSection careerProfile -CivaCategory projects
        let defaults = UserDefaults.standard
        section = defaults.string(forKey: "CivaSection").flatMap(AppSection.init) ?? section
        profileCategory = defaults.string(forKey: "CivaCategory").flatMap(ProfileCategory.init) ?? profileCategory
        #endif
    }
}
