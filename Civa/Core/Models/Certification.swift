//
//  Certification.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

@Model
nonisolated final class Certification: ReviewTracked {
    var id = UUID()
    var name: String
    var issuer: String
    var issued: YearMonth?
    var expires: YearMonth?
    var credentialID: String
    var credentialURL: String
    var customFields: [CustomField]
    var statusRaw: String

    init(
        name: String,
        issuer: String = "",
        issued: YearMonth? = nil,
        expires: YearMonth? = nil,
        credentialID: String = "",
        credentialURL: String = "",
        customFields: [CustomField] = [],
        status: ReviewStatus = .confirmed
    ) {
        self.name = name
        self.issuer = issuer
        self.issued = issued
        self.expires = expires
        self.credentialID = credentialID
        self.credentialURL = credentialURL
        self.customFields = customFields
        self.statusRaw = status.rawValue
    }
}
