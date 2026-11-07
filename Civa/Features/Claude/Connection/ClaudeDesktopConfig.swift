//
//  ClaudeDesktopConfig.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit
import Foundation

/// Adds and removes Civa's entry in Claude Desktop's `claude_desktop_config.json`, keeping
/// everything else in the file. Civa is sandboxed, so the user grants the Claude folder once in
/// an Open panel each time Civa changes the file (FR-070).
nonisolated enum ClaudeDesktopConfig {
    static let serverName = "civa"
    static let fileName = "claude_desktop_config.json"
    static let claudeBundleID = "com.anthropic.claudefordesktop"

    enum Failure: LocalizedError {
        case unreadable
        case wrongFolder

        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "Claude Desktop's settings file isn't valid JSON, so Civa left it alone.")
            case .wrongFolder: String(localized: "Choose the folder named Claude, inside Application Support.")
            }
        }
    }

    /// `~/Library/Application Support/Claude` in the real home folder, not Civa's container.
    static var folder: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(filePath: home).appending(path: "Library/Application Support/Claude", directoryHint: .isDirectory)
    }

    /// The config with Civa's entry added or replaced. `existing` is nil when there's no file yet.
    static func adding(executable: String, to existing: Data?) throws -> Data {
        var config = try object(existing)
        var servers = config["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = ["command": executable, "args": [ClaudeLink.helperArgument]]
        config["mcpServers"] = servers
        return try data(config)
    }

    /// The config without Civa's entry.
    static func removing(from existing: Data?) throws -> Data {
        var config = try object(existing)
        var servers = config["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = nil
        config["mcpServers"] = servers.isEmpty ? nil : servers
        return try data(config)
    }

    /// The command in Civa's entry, if there is one.
    static func command(in existing: Data?) -> String? {
        guard let config = try? object(existing) else { return nil }
        return ((config["mcpServers"] as? [String: Any])?[serverName] as? [String: Any])?["command"] as? String
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.unreadable }
        return object
    }

    private static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Asks for the Claude folder, then rewrites the config there with `change`.
    @MainActor
    static func update(prompt: String, _ change: (Data?) throws -> Data) throws -> Bool {
        let panel = NSOpenPanel()
        panel.directoryURL = folder
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = prompt
        panel.message = String(localized: "Civa needs your OK to change Claude Desktop's settings. Click \(prompt) to allow it this once.")
        guard panel.runModal() == .OK, let chosen = panel.url else { return false }
        guard chosen.standardizedFileURL.path == folder.standardizedFileURL.path else { throw Failure.wrongFolder }
        let scoped = chosen.startAccessingSecurityScopedResource()
        defer { if scoped { chosen.stopAccessingSecurityScopedResource() } }
        let file = chosen.appending(path: fileName)
        let existing = try? Data(contentsOf: file)
        try change(existing).write(to: file, options: .atomic)
        return true
    }

    static var isClaudeInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) != nil
    }

    @MainActor
    static func openClaude() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
