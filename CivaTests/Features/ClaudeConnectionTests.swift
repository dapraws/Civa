//
//  ClaudeConnectionTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct ClaudeConnectionTests {
    private func json(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func addingKeepsEverythingElse() throws {
        let existing = Data(#"{"preferences":{"theme":"dark"},"mcpServers":{"other":{"command":"/bin/other"}}}"#.utf8)
        let updated = try ClaudeDesktopConfig.adding(executable: "/Applications/Civa.app/Contents/MacOS/Civa", to: existing)
        let config = try json(updated)
        #expect((config["preferences"] as? [String: String])?["theme"] == "dark")
        let servers = try #require(config["mcpServers"] as? [String: Any])
        #expect(servers["other"] != nil)
        #expect(ClaudeDesktopConfig.command(in: updated) == "/Applications/Civa.app/Contents/MacOS/Civa")
        let civa = try #require(servers["civa"] as? [String: Any])
        #expect(civa["args"] as? [String] == ["--mcp"])
    }

    @Test func addingWorksWithoutAFile() throws {
        let updated = try ClaudeDesktopConfig.adding(executable: "/x/Civa", to: nil)
        #expect(ClaudeDesktopConfig.command(in: updated) == "/x/Civa")
    }

    @Test func removingLeavesOtherServers() throws {
        let both = try ClaudeDesktopConfig.adding(executable: "/x/Civa", to: Data(#"{"mcpServers":{"other":{}}}"#.utf8))
        let removed = try json(ClaudeDesktopConfig.removing(from: both))
        #expect((removed["mcpServers"] as? [String: Any])?.keys.sorted() == ["other"])

        let only = try ClaudeDesktopConfig.adding(executable: "/x/Civa", to: Data(#"{"preferences":{}}"#.utf8))
        #expect(try json(ClaudeDesktopConfig.removing(from: only))["mcpServers"] == nil)
    }

    @Test func refusesAFileItCantRead() {
        #expect(throws: ClaudeDesktopConfig.Failure.self) {
            try ClaudeDesktopConfig.adding(executable: "/x/Civa", to: Data("{ not json".utf8))
        }
    }

    @Test func helperAnswersTheHandshakeAndForwardsCalls() throws {
        let initialize = try #require(ClaudeHelper.respond(to: Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#.utf8)) { _ in nil })
        #expect((initialize["result"] as? [String: Any])?["protocolVersion"] as? String == "2025-06-18")
        #expect(ClaudeHelper.respond(to: Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)) { _ in nil } == nil)

        var asked: ClaudeLink.Request?
        let call = try #require(ClaudeHelper.respond(to: Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"check_connection","arguments":{"x":"1"}}}"#.utf8)) { request in
            asked = request
            return ClaudeLink.Reply(ok: true, text: "Connected")
        })
        #expect(asked?.tool == "check_connection")
        #expect(asked?.arguments == ["x": "1"])
        #expect((call["result"] as? [String: Any])?["isError"] as? Bool == false)

        let closed = try #require(ClaudeHelper.respond(to: Data(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"check_connection"}}"#.utf8)) { _ in nil })
        #expect((closed["result"] as? [String: Any])?["isError"] as? Bool == true)
    }

    @Test func bridgeAnswersOverItsSocket() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "t\(UInt16.random(in: 0...9999)).sock").path(percentEncoded: false)
        let bridge = ClaudeBridge(path: path)
        bridge.start()
        defer { bridge.stop() }
        #expect(bridge.isListening)
        // The bridge answers on the main actor, so the client runs off it while the test awaits.
        let reply = await Task.detached { ClaudeLink.ask(.init(tool: "check_connection"), path: path) }.value
        #expect(reply?.ok == true)
        #expect(bridge.lastConnected != nil)
    }
}
