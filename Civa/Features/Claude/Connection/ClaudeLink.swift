//
//  ClaudeLink.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Darwin
import Foundation

/// What Civa and its Claude Desktop helper share. The helper is Civa's own executable started
/// with `--mcp`, so it runs in Civa's sandbox and reaches the app through a socket in Civa's
/// container, which other apps can't open. The helper owns no data: every tool call is answered
/// by the running app, which checks permissions and logs it (FR-071, FR-074).
nonisolated enum ClaudeLink {
    /// Claude Desktop starts the helper with this argument.
    static let helperArgument = "--mcp"

    /// One request per connection, one JSON line each way.
    struct Request: Codable {
        var tool: String
        var arguments: [String: String] = [:]
    }

    struct Reply: Codable {
        var ok: Bool
        var text: String
    }

    /// Sent by the helper when Claude Desktop starts it, before any tool call.
    static let hello = "hello"

    struct Tool {
        let name: String
        let description: String
        /// The permission the tool needs; nil for tools anyone connected may call.
        var category: ClaudeCategory?
        /// Argument name → description. All arguments are strings.
        var arguments: [String: String] = [:]
        var required: [String] = []
    }

    /// Every tool Claude sees. Civa decides at call time whether the user allows it.
    static let tools: [Tool] = [
        Tool(
            name: "check_connection",
            description: "Check that Civa, the user's local career workspace on this Mac, is open and connected, and which categories it shares with Claude. Call this first."
        ),
        Tool(name: "get_personal_info", description: "The user's name, headline, summary, contact details, and links.", category: .personal),
        Tool(name: "list_experience", description: "The user's professional and organizational experience: roles, dates, results, and skills used.", category: .experience),
        Tool(name: "list_education", description: "The user's education: degrees, grades, thesis, coursework, and honors.", category: .education),
        Tool(name: "list_projects", description: "The user's projects: role, links, dates, results, and skills used.", category: .projects),
        Tool(name: "list_achievements_and_certifications", description: "The user's awards, placements, and certifications.", category: .recognition),
        Tool(name: "list_skills", description: "The user's skills, grouped by category.", category: .skills),
        Tool(name: "list_resumes", description: "The resumes saved in Civa, with their ids, targets, and which one is the Master Resume.", category: .resumes),
        Tool(
            name: "get_resume", description: "The full text of one resume in Civa.", category: .resumes,
            arguments: ["resume_id": "The id from list_resumes."], required: ["resume_id"]
        ),
        Tool(name: "list_applications", description: "The job applications the user tracks in Civa: company, position, status, and the resume sent.", category: .applications),
        Tool(
            name: "get_application", description: "One job application with its full job description.", category: .applications,
            arguments: ["application_id": "The id from list_applications."], required: ["application_id"]
        ),
    ]

    static func tool(named name: String) -> Tool? {
        tools.first { $0.name == name }
    }

    /// The socket, in the container's temporary folder: both the app and the helper resolve the same path.
    static var socketPath: String {
        FileManager.default.temporaryDirectory.appending(path: "claude.sock").path(percentEncoded: false)
    }

    static func socketAddress(_ path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        // ponytail: very long home folder paths don't fit sun_path (104 bytes); a shorter folder would be needed then.
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return address
    }

    /// Reads up to the first newline, or until the other side closes.
    static func readLine(from fd: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while !data.contains(0x0A) {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer[0..<count])
        }
        if let newline = data.firstIndex(of: 0x0A) { data = data[..<newline] }
        return data
    }

    static func writeLine(_ data: Data, to fd: Int32) -> Bool {
        var line = data
        line.append(0x0A)
        return line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) } == line.count
    }

    /// Asks the running app; nil when Civa isn't open.
    static func ask(_ request: Request, path: String = socketPath) -> Reply? {
        guard var address = socketAddress(path) else { return nil }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0, let data = try? JSONEncoder().encode(request), writeLine(data, to: fd) else { return nil }
        return try? JSONDecoder().decode(Reply.self, from: readLine(from: fd))
    }
}
