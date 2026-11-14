//
//  WorkspaceRegistryTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import Civa

@MainActor
struct WorkspaceRegistryTests {
    private let defaults = UserDefaults(suiteName: "WorkspaceRegistryTests-\(UUID())")!
    private let root = URL.temporaryDirectory.appending(path: "Workspaces-\(UUID())")
    private let original = URL.temporaryDirectory.appending(path: "Original-\(UUID())/Civa.store")

    private func registry() -> WorkspaceRegistry {
        WorkspaceRegistry(defaults: defaults, root: root, originalStoreURL: original, trash: { try FileManager.default.removeItem(at: $0) })
    }

    @Test func firstLaunchUsesTheExistingStore() {
        let workspaces = registry()
        #expect(workspaces.all.count == 1)
        #expect(workspaces.current.isOriginal)
        #expect(workspaces.storeURL(for: workspaces.current) == nil)
        #expect(workspaces.tipsURL(for: workspaces.current) == nil)
    }

    @Test func newWorkspaceGetsItsOwnFolder() throws {
        let workspaces = registry()
        let najla = try workspaces.create(name: "  Najla ")
        #expect(najla.name == "Najla")
        #expect(workspaces.storeURL(for: najla) == root.appending(path: "\(najla.id.uuidString)/Civa.store"))
        #expect(workspaces.tipsURL(for: najla) == root.appending(path: "\(najla.id.uuidString)/Tips"))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: najla.id.uuidString).path))
        #expect(workspaces.all.map(\.name).contains("Najla"))
    }

    @Test func namesMustBeFilledAndUnique() throws {
        let workspaces = registry()
        _ = try workspaces.create(name: "Najla")
        #expect(throws: WorkspaceError.emptyName) { try workspaces.create(name: "   ") }
        #expect(throws: WorkspaceError.duplicateName) { try workspaces.create(name: "najla") }
        let other = try workspaces.create(name: "Rina")
        #expect(throws: WorkspaceError.duplicateName) { try workspaces.rename(other.id, to: "NAJLA ") }
        try workspaces.rename(other.id, to: "Rina W")
        #expect(workspaces.all.first { $0.id == other.id }?.name == "Rina W")
    }

    @Test func switchingSwapsEachWorkspacesOwnPreferences() throws {
        let workspaces = registry()
        let darrel = workspaces.current
        defaults.set(false, forKey: OviStore.isShownKey)
        defaults.set(true, forKey: Onboarding.welcomeShownKey)
        defaults.set(["experience"], forKey: "ClaudeReadCategories")
        defaults.set("dark", forKey: "appearance")
        let najla = try workspaces.create(name: "Najla")

        workspaces.switchTo(najla.id)
        #expect(workspaces.current.id == najla.id)
        #expect(defaults.object(forKey: OviStore.isShownKey) == nil)
        #expect(defaults.object(forKey: Onboarding.welcomeShownKey) == nil)
        #expect(defaults.object(forKey: "ClaudeReadCategories") == nil)
        // Shared across workspaces.
        #expect(defaults.string(forKey: "appearance") == "dark")
        defaults.set(true, forKey: Onboarding.checklistHiddenKey)

        workspaces.switchTo(darrel.id)
        #expect(defaults.bool(forKey: OviStore.isShownKey) == false)
        #expect(defaults.object(forKey: OviStore.isShownKey) != nil)
        #expect(defaults.bool(forKey: Onboarding.welcomeShownKey))
        #expect(defaults.stringArray(forKey: "ClaudeReadCategories") == ["experience"])
        #expect(defaults.object(forKey: Onboarding.checklistHiddenKey) == nil)

        workspaces.switchTo(najla.id)
        #expect(defaults.bool(forKey: Onboarding.checklistHiddenKey))
    }

    @Test func listAndCurrentSurviveARelaunch() throws {
        let najla = try registry().create(name: "Najla")
        registry().switchTo(najla.id)
        let again = registry()
        #expect(again.current.id == najla.id)
        #expect(again.all.count == 2)
    }

    @Test func deletingMovesTheFolderAwayButNeverTheCurrentOne() throws {
        let workspaces = registry()
        let najla = try workspaces.create(name: "Najla")
        #expect(throws: WorkspaceError.isCurrent) { try workspaces.delete(workspaces.current.id) }
        try workspaces.delete(najla.id)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: najla.id.uuidString).path))
        #expect(workspaces.all.count == 1)
    }

    @Test func deletingTheOriginalMovesItsStoreFilesAway() throws {
        let workspaces = registry()
        let darrel = workspaces.current
        let folder = original.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["Civa.store", "Civa.store-shm", "Civa.store-wal", ".Civa_SUPPORT", "Other.store"] {
            FileManager.default.createFile(atPath: folder.appending(path: name).path, contents: Data())
        }
        let najla = try workspaces.create(name: "Najla")
        workspaces.switchTo(najla.id)
        try workspaces.delete(darrel.id)
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(left == ["Other.store"])
        #expect(workspaces.all.map(\.id) == [najla.id])
    }

    @Test func originalIsNamedOnceFromTheProfile() throws {
        let workspaces = registry()
        #expect(workspaces.current.displayName == String(localized: "My Workspace"))
        workspaces.nameOriginalIfNeeded("Darrel Prawira")
        #expect(workspaces.current.name == "Darrel Prawira")
        try workspaces.rename(workspaces.current.id, to: "Darrel")
        workspaces.nameOriginalIfNeeded("Someone Else")
        #expect(workspaces.current.name == "Darrel")
    }

    /// Deleting the original workspace must trash the file SwiftData really opens.
    @Test func originalStoreIsWhereSwiftDataKeepsIt() {
        let configuration = ModelConfiguration("Civa", schema: Schema(versionedSchema: SchemaV1.self))
        #expect(WorkspaceRegistry.defaultOriginalStoreURL == configuration.url)
    }
}
