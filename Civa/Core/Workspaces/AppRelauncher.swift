//
//  AppRelauncher.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import AppKit

/// Restarts Civa for the user, such as after switching workspaces: opens a new copy, which waits
/// for this one to quit before it starts, then quits.
enum AppRelauncher {
    private static let waitKey = "CivaRelaunchAfter"

    /// Opens a new Civa and quits this one. Calls `failed` when the new copy can't open.
    static func relaunch(failed: @escaping @MainActor @Sendable (Error) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["-\(waitKey)", String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error { failed(error) } else { NSApp.terminate(nil) }
            }
        }
    }

    /// In the new copy: the old one still holds the store and the Claude socket (which it removes
    /// as it quits), so wait for it to exit. Gives up after 10 seconds.
    static func waitForPreviousInstance() {
        let pid = pid_t(UserDefaults.standard.integer(forKey: waitKey))
        guard pid > 0 else { return }
        let deadline = Date.now.addingTimeInterval(10)
        while kill(pid, 0) == 0, Date.now < deadline {
            usleep(100_000)
        }
    }
}
