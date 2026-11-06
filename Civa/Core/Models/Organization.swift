//
//  Organization.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

/// The website picked for a company or school name, used to show its logo. Matched by name,
/// so one pick shows the logo in Experience, Education, and Applications alike.
@Model
nonisolated final class Organization {
    #Unique<Organization>([\.key])

    /// The name, trimmed and lowercased.
    var key: String
    var name: String
    var domain: String

    init(name: String, domain: String) {
        self.key = Organization.key(for: name)
        self.name = name
        self.domain = domain
    }

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
