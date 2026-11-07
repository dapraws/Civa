//
//  ResumeSnapshot.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import SwiftData

nonisolated enum SnapshotReason: String, Codable {
    case created, exported, checkpoint, beforeRestore, beforeClaude, createdByClaude

    var title: String {
        switch self {
        case .created: String(localized: "Created")
        case .exported: String(localized: "Exported")
        case .checkpoint: String(localized: "Checkpoint")
        case .beforeRestore: String(localized: "Before Restore")
        case .beforeClaude: String(localized: "Before Claude's Changes")
        case .createdByClaude: String(localized: "Created by Claude")
        }
    }
}

/// A saved version of a resume's content and format, taken at milestones (FR-043).
/// The resume's name, target position, and job description aren't part of it.
@Model
nonisolated final class ResumeSnapshot {
    var id = UUID()
    var createdAt: Date
    var reasonRaw: String
    /// Optional label for a manual checkpoint.
    var name: String
    var documentData: Data
    var resume: Resume?

    var reason: SnapshotReason {
        get { SnapshotReason(rawValue: reasonRaw) ?? .checkpoint }
        set { reasonRaw = newValue.rawValue }
    }

    var document: ResumeDocument {
        (try? JSONDecoder().decode(ResumeDocument.self, from: documentData)) ?? .blank
    }

    init(reason: SnapshotReason, name: String = "", document: ResumeDocument, createdAt: Date = .now) {
        self.createdAt = createdAt
        self.reasonRaw = reason.rawValue
        self.name = name
        self.documentData = (try? JSONEncoder().encode(document)) ?? Data()
    }
}

extension Resume {
    /// Newest first.
    var history: [ResumeSnapshot] {
        snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    /// Records the current content as a version. Skipped when it matches the latest version,
    /// except for a checkpoint the user asked for. The caller saves.
    @discardableResult
    func recordSnapshot(_ reason: SnapshotReason, name: String = "", in context: ModelContext) -> ResumeSnapshot? {
        let current = document
        guard reason == .checkpoint || history.first?.document != current else { return nil }
        let snapshot = ResumeSnapshot(reason: reason, name: name, document: current)
        context.insert(snapshot)
        snapshot.resume = self
        return snapshot
    }
}
