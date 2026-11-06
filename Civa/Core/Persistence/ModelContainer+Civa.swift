//
//  ModelContainer+Civa.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

extension ModelContainer {
    /// Civa's store. Pass `storeURL` to open a specific file (tests) or `inMemory` for previews.
    static func civa(storeURL: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL)
        } else {
            ModelConfiguration("Civa", schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: CivaMigrationPlan.self,
            configurations: configuration
        )
    }
}
