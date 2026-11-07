//
//  ClaudeBridge.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Darwin
import Foundation
import Observation

/// Civa's side of the Claude Desktop connection (FR-070). While connected, it listens on the
/// socket in Civa's container and answers the helper. Civa stays the only process that reads or
/// changes the store, so permissions and the audit log live in one place.
@Observable
final class ClaudeBridge {
    static let shared = ClaudeBridge()

    static let enabledKey = "ClaudeConnectionEnabled"
    static let lastConnectedKey = "ClaudeLastConnected"

    /// Set up and not disconnected. Only then does Civa listen.
    private(set) var isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    private(set) var isListening = false
    /// The last time Claude Desktop's helper reached Civa.
    private(set) var lastConnected = UserDefaults.standard.object(forKey: lastConnectedKey) as? Date
    private(set) var problem: String?

    /// Answers one request on the main actor. Replaced by later features as tools are added.
    @ObservationIgnored var handler: @MainActor (ClaudeLink.Request) -> ClaudeLink.Reply = { ClaudeBridge.defaultReply($0) }

    @ObservationIgnored private var source: DispatchSourceRead?
    @ObservationIgnored private let path: String

    init(path: String = ClaudeLink.socketPath) {
        self.path = path
    }

    /// Call at launch; listens only when the connection is set up.
    func startIfEnabled() {
        if isEnabled { start() }
    }

    func enable() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        start()
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        stop()
    }

    func start() {
        guard source == nil else { return }
        guard var address = ClaudeLink.socketAddress(path) else {
            problem = String(localized: "Civa's folder path is too long for a connection.")
            return
        }
        unlink(path)  // left over if Civa quit unexpectedly
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard fd >= 0, bound == 0, listen(fd, 8) == 0 else {
            problem = String(localized: "Civa couldn't start listening for Claude Desktop (error \(errno)).")
            if fd >= 0 { close(fd) }
            return
        }
        chmod(path, 0o600)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [self] in
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            serve(client)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        isListening = true
        problem = nil
    }

    func stop() {
        source?.cancel()
        source = nil
        unlink(path)
        isListening = false
    }

    /// Reads and writes off the main thread; answers on it.
    private func serve(_ client: Int32) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var timeout = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            guard let request = try? JSONDecoder().decode(ClaudeLink.Request.self, from: ClaudeLink.readLine(from: client)) else {
                close(client)
                return
            }
            DispatchQueue.main.async { [self] in
                let reply = MainActor.assumeIsolated { answer(request) }
                DispatchQueue.global(qos: .userInitiated).async {
                    if let data = try? JSONEncoder().encode(reply) { _ = ClaudeLink.writeLine(data, to: client) }
                    close(client)
                }
            }
        }
    }

    func answer(_ request: ClaudeLink.Request) -> ClaudeLink.Reply {
        lastConnected = .now
        if self === Self.shared { UserDefaults.standard.set(lastConnected, forKey: Self.lastConnectedKey) }
        if request.tool == ClaudeLink.hello { return ClaudeLink.Reply(ok: true, text: "") }
        return handler(request)
    }

    static func defaultReply(_ request: ClaudeLink.Request) -> ClaudeLink.Reply {
        switch request.tool {
        case "check_connection":
            ClaudeLink.Reply(ok: true, text: "Civa is open and connected. It isn't sharing any Career Profile data yet; the user chooses what Claude may read in Civa's Settings.")
        default:
            ClaudeLink.Reply(ok: false, text: "Civa doesn't offer the tool \(request.tool).")
        }
    }
}
