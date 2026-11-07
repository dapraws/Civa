//
//  ClaudeHelper.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// The MCP server Claude Desktop starts (`Civa --mcp`): newline-delimited JSON-RPC on stdin and
/// stdout. It never opens the store; tool calls go to the running app through `ClaudeLink`.
nonisolated enum ClaudeHelper {
    static func run() {
        _ = ClaudeLink.ask(ClaudeLink.Request(tool: ClaudeLink.hello))
        while let line = readLine(strippingNewline: true) {
            if let reply = respond(to: Data(line.utf8)) { send(reply) }
        }
    }

    /// The JSON-RPC reply to one message, or nil for notifications. `ask` is swappable for tests.
    static func respond(
        to line: Data,
        ask: (ClaudeLink.Request) -> ClaudeLink.Reply? = { ClaudeLink.ask($0) }
    ) -> [String: Any]? {
        guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let method = message["method"] as? String,
              let id = message["id"]
        else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        func result(_ value: [String: Any]) -> [String: Any] { ["jsonrpc": "2.0", "id": id, "result": value] }

        switch method {
        case "initialize":
            return result([
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "civa", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"],
                "instructions": "Civa is the user's career workspace on this Mac. It shares only what the user allows, and any change you suggest waits for the user's approval in Civa. Civa must be open. When the user wants a resume, tailoring, or better wording and Civa is connected, do it in Civa with create_resume_draft, suggest_resume_edit, or suggest_profile_edit rather than writing it elsewhere, so it keeps Civa's ATS-safe layout and the user's confirmed facts. When the user shares a CV or profile text, offer to send its records to Civa with suggest_profile_records. When asked to run Civa requests, call get_pending_requests.",
            ])
        case "tools/list":
            return result(["tools": (ClaudeLink.tools + ClaudeLink.writeTools).map(definition)])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            // Lists and objects travel as JSON text; Civa decodes the ones it expects.
            let arguments = (params["arguments"] as? [String: Any] ?? [:]).compactMapValues { value -> String? in
                if let text = value as? String { return text }
                if let flag = value as? Bool { return flag ? "true" : "false" }
                guard JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            let reply = ask(ClaudeLink.Request(tool: name, arguments: arguments))
                ?? ClaudeLink.Reply(ok: false, text: "Civa can't be reached. Either Civa isn't open, or the user turned off Claude's connection in Civa's Settings. Ask the user to open Civa and check its Claude Desktop setting.")
            return result(["content": [["type": "text", "text": reply.text]], "isError": !reply.ok])
        case "ping":
            return result([:])
        default:
            return ["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Unknown method \(method)"]]
        }
    }

    private static func definition(_ tool: ClaudeLink.Tool) -> [String: Any] {
        let properties = (try? JSONSerialization.jsonObject(with: Data(tool.schema.utf8)) as? [String: Any])
            ?? tool.arguments.mapValues { ["type": "string", "description": $0] }
        return [
            "name": tool.name,
            "description": tool.description,
            "inputSchema": ["type": "object", "properties": properties, "required": tool.required],
        ]
    }

    private static func send(_ message: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        FileHandle.standardOutput.write(data)
    }
}
