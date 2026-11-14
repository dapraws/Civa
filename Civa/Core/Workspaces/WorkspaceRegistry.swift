//
//  WorkspaceRegistry.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import Observation

/// One person's Civa: their own career data, plus their own Ovi, welcome, Getting Started and
/// Claude permissions. Appearance, logo lookup and the Claude Desktop connection are shared.
nonisolated struct Workspace: Codable, Identifiable, Hashable {
    let id: UUID
    /// Empty until named; the first workspace takes the profile's full name.
    var name: String
    /// The workspace that existed before workspaces: it keeps Civa's original store in place,
    /// so nothing is moved or copied.
    var isOriginal: Bool

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "My Workspace") : name
    }
}

nonisolated enum WorkspaceError: LocalizedError, Equatable {
    case emptyName, duplicateName, isCurrent

    var errorDescription: String? {
        switch self {
        case .emptyName: String(localized: "Give the workspace a name.")
        case .duplicateName: String(localized: "Another workspace already has that name.")
        case .isCurrent: String(localized: "Switch to another workspace before deleting this one.")
        }
    }
}

/// The workspaces on this Mac and which one is open. The list lives in the shared preferences;
/// each new workspace has a folder with its own store and tips. Switching swaps the preferences
/// that belong to a workspace and needs a restart, which opens the other store.
@Observable
final class WorkspaceRegistry {
    static let shared = WorkspaceRegistry()

    /// Preferences that belong to one workspace. Everything else is shared.
    static let workspaceKeys = [
        OviStore.isShownKey, OviStore.tipStateKey, OviStore.shownTodayKey,
        Onboarding.welcomeShownKey, Onboarding.checklistHiddenKey,
        "ClaudeReadCategories", "ClaudeSuggestCategories",
    ]
    private static let listKey = "Workspaces"
    private static let currentKey = "CurrentWorkspace"
    private static let savedPrefix = "WorkspacePreferences."

    /// Where SwiftData keeps `ModelConfiguration("Civa")`: the original workspace's store.
    static let defaultOriginalStoreURL = URL.applicationSupportDirectory.appending(path: "Civa.store")

    private(set) var all: [Workspace]
    private(set) var currentID: UUID

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let root: URL
    @ObservationIgnored private let originalStoreURL: URL
    @ObservationIgnored private let trash: (URL) throws -> Void

    init(
        defaults: UserDefaults = .standard,
        root: URL = .applicationSupportDirectory.appending(path: "Workspaces"),
        originalStoreURL: URL = WorkspaceRegistry.defaultOriginalStoreURL,
        trash: @escaping (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) {
        self.defaults = defaults
        self.root = root
        self.originalStoreURL = originalStoreURL
        self.trash = trash
        var list = (defaults.data(forKey: Self.listKey)).flatMap { try? JSONDecoder().decode([Workspace].self, from: $0) } ?? []
        if list.isEmpty {
            list = [Workspace(id: UUID(), name: "", isOriginal: true)]
        }
        all = list
        let saved = defaults.string(forKey: Self.currentKey).flatMap(UUID.init(uuidString:))
        currentID = list.contains { $0.id == saved } ? saved! : list[0].id
        persist()
    }

    var current: Workspace {
        all.first { $0.id == currentID } ?? all[0]
    }

    /// nil: the original store, where SwiftData puts it by default.
    func storeURL(for workspace: Workspace) -> URL? {
        workspace.isOriginal ? nil : folder(workspace.id).appending(path: "Civa.store")
    }

    /// nil: TipKit's default place, which the original workspace already uses.
    func tipsURL(for workspace: Workspace) -> URL? {
        workspace.isOriginal ? nil : folder(workspace.id).appending(path: "Tips")
    }

    @discardableResult
    func create(name: String) throws -> Workspace {
        let name = try validated(name, excluding: nil)
        let workspace = Workspace(id: UUID(), name: name, isOriginal: false)
        try FileManager.default.createDirectory(at: folder(workspace.id), withIntermediateDirectories: true)
        all.append(workspace)
        persist()
        return workspace
    }

    func rename(_ id: UUID, to name: String) throws {
        let name = try validated(name, excluding: id)
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].name = name
        persist()
    }

    /// Moves the workspace's data to the Trash (recoverable) and forgets it.
    func delete(_ id: UUID) throws {
        guard id != currentID else { throw WorkspaceError.isCurrent }
        guard let workspace = all.first(where: { $0.id == id }) else { return }
        if workspace.isOriginal {
            let folder = originalStoreURL.deletingLastPathComponent()
            let base = originalStoreURL.lastPathComponent
            let stem = originalStoreURL.deletingPathExtension().lastPathComponent
            // The store, its journal files, and SwiftData's folder for large attributes (documents).
            for name in [base, "\(base)-shm", "\(base)-wal", ".\(stem)_SUPPORT"] {
                let url = folder.appending(path: name)
                if FileManager.default.fileExists(atPath: url.path) { try trash(url) }
            }
        } else if FileManager.default.fileExists(atPath: folder(id).path) {
            try trash(folder(id))
        }
        all.removeAll { $0.id == id }
        defaults.removeObject(forKey: Self.savedPrefix + id.uuidString)
        persist()
    }

    /// Saves this workspace's own preferences, loads the other's, and makes it current. The
    /// caller restarts Civa so the other store and tips open.
    func switchTo(_ id: UUID) {
        guard id != currentID, all.contains(where: { $0.id == id }) else { return }
        var saved: [String: Any] = [:]
        for key in Self.workspaceKeys {
            if let value = defaults.object(forKey: key) { saved[key] = value }
        }
        defaults.set(saved, forKey: Self.savedPrefix + currentID.uuidString)
        let target = defaults.dictionary(forKey: Self.savedPrefix + id.uuidString) ?? [:]
        for key in Self.workspaceKeys {
            defaults.set(target[key], forKey: key)
        }
        currentID = id
        persist()
    }

    /// The first workspace takes the profile's full name, once.
    func nameOriginalIfNeeded(_ fullName: String) {
        let fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullName.isEmpty, let index = all.firstIndex(where: { $0.isOriginal && $0.name.isEmpty }),
              !all.contains(where: { $0.name.caseInsensitiveCompare(fullName) == .orderedSame })
        else { return }
        all[index].name = fullName
        persist()
    }

    private func folder(_ id: UUID) -> URL {
        root.appending(path: id.uuidString)
    }

    private func validated(_ name: String, excluding id: UUID?) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorkspaceError.emptyName }
        let taken = all.contains { $0.id != id && $0.displayName.caseInsensitiveCompare(name) == .orderedSame }
        guard !taken else { throw WorkspaceError.duplicateName }
        return name
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(all), forKey: Self.listKey)
        defaults.set(currentID.uuidString, forKey: Self.currentKey)
    }
}
