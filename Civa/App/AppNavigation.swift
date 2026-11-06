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

    init() {
        #if DEBUG
        // Open on a given page for manual checks: -CivaSection careerProfile -CivaCategory projects
        let defaults = UserDefaults.standard
        section = defaults.string(forKey: "CivaSection").flatMap(AppSection.init) ?? section
        profileCategory = defaults.string(forKey: "CivaCategory").flatMap(ProfileCategory.init) ?? profileCategory
        #endif
    }
}
