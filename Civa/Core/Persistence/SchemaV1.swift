//
//  SchemaV1.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData

// ponytail: models are top-level and listed here. Before adding SchemaV2,
// copy the V1 model shapes into this namespace so V1 stays frozen for migration.
nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            PersonalInfo.self,
            Experience.self,
            Education.self,
            Project.self,
            Achievement.self,
            Certification.self,
            Skill.self,
            JobApplication.self,
        ]
    }
}

nonisolated enum CivaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
