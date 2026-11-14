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

    /// Delete says the data can be put back from the Trash: putting the folder back brings the
    /// workspace back, name and preferences included.
    @Test func workspacePutBackFromTheTrashReturns() throws {
        let bin = URL.temporaryDirectory.appending(path: "Bin-\(UUID())")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let workspaces = WorkspaceRegistry(defaults: defaults, root: root, originalStoreURL: original, trash: {
            try FileManager.default.moveItem(at: $0, to: bin.appending(path: $0.lastPathComponent))
        })
        let najla = try workspaces.create(name: "Najla")
        try workspaces.delete(najla.id)
        #expect(registry().all.count == 1)
        try FileManager.default.moveItem(at: bin.appending(path: najla.id.uuidString), to: root.appending(path: najla.id.uuidString))
        #expect(registry().all.first { $0.id == najla.id }?.name == "Najla")
    }

    @Test func originalPutBackFromTheTrashReturns() throws {
        let workspaces = registry()
        let najla = try workspaces.create(name: "Najla")
        workspaces.switchTo(najla.id)
        try workspaces.delete(workspaces.all.first { $0.isOriginal }!.id)
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: original.path, contents: Data())
        #expect(registry().all.contains { $0.isOriginal })
    }

    /// A list that can't be read is rebuilt from the folders, never replaced by an empty one.
    @Test func unreadableListIsRebuiltFromFolders() throws {
        let najla = try registry().create(name: "Najla")
        defaults.set(Data("not json".utf8), forKey: "Workspaces")
        let again = registry()
        #expect(again.all.contains { $0.id == najla.id && $0.name == "Najla" })
        #expect(again.all.contains { $0.isOriginal })
    }

    @Test func originalIsNeverNamedFromAnotherWorkspacesProfile() throws {
        let workspaces = registry()
        let work = try workspaces.create(name: "Work")
        workspaces.switchTo(work.id)
        workspaces.nameOriginalIfNeeded("Bob Smith")
        #expect(workspaces.all.first { $0.isOriginal }?.name == "")
    }

    /// The swap happens in the new copy at launch, so the closing copy's writes stay in its own
    /// workspace.
    @Test func scheduledSwitchHappensAtTheNextLaunch() throws {
        let workspaces = registry()
        let darrel = workspaces.current
        let najla = try workspaces.create(name: "Najla")
        defaults.set(true, forKey: Onboarding.welcomeShownKey)
        workspaces.scheduleSwitch(to: najla.id)
        #expect(workspaces.current.id == darrel.id)
        defaults.set(true, forKey: Onboarding.checklistHiddenKey)  // written while closing

        let next = registry()
        #expect(next.current.id == najla.id)
        #expect(defaults.object(forKey: Onboarding.welcomeShownKey) == nil)
        #expect(defaults.object(forKey: Onboarding.checklistHiddenKey) == nil)
        next.switchTo(darrel.id)
        #expect(defaults.bool(forKey: Onboarding.checklistHiddenKey))
        #expect(registry().current.id == darrel.id)
    }

    @Test func cancelledSwitchDoesNothingAtLaunch() throws {
        let workspaces = registry()
        let najla = try workspaces.create(name: "Najla")
        workspaces.scheduleSwitch(to: najla.id)
        workspaces.cancelScheduledSwitch()
        #expect(registry().current.id == workspaces.current.id)
    }
}
