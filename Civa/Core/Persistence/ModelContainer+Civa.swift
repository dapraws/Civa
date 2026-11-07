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
    /// Autosave is off: every write is saved explicitly, and inline editing relies on rollback.
    static func civa(storeURL: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL)
        } else {
            ModelConfiguration("Civa", schema: schema, isStoredInMemoryOnly: inMemory)
        }
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CivaMigrationPlan.self,
            configurations: configuration
        )
        container.mainContext.autosaveEnabled = false
        convertTextGrades(in: container.mainContext)
        return container
    }

    /// Grades used to be free text; read the ones that parse into a number and scale.
    /// ponytail: runs on every launch (one fetch of Education); move into a SchemaV2 migration stage once released.
    private static func convertTextGrades(in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<Education>(predicate: #Predicate { $0.gradeValue == nil && $0.grade != "" }))) ?? []
        guard records.map({ $0.convertTextGrade() }).contains(true) else { return }
        try? context.save()
    }
}
