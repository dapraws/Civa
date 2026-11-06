//
//  PersonalInfo.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class PersonalInfo: ReviewTracked {
    var id = UUID()
    var fullName: String
    var headline: String
    var email: String
    var phone: String
    var location: String
    var links: [ProfileLink]
    var customFields: [CustomField]
    var statusRaw: String

    init(
        fullName: String,
        headline: String = "",
        email: String = "",
        phone: String = "",
        location: String = "",
        links: [ProfileLink] = [],
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.fullName = fullName
        self.headline = headline
        self.email = email
        self.phone = phone
        self.location = location
        self.links = links
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
