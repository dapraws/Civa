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

    /// In the new copy: wait for the old one to quit, so two Civas never run at once (one window,
    /// one Claude connection). Gives up after 10 seconds. `kill(pid, 0)` can't see other apps
    /// from the sandbox, so this asks AppKit.
    static func waitForPreviousInstance() {
        let pid = pid_t(UserDefaults.standard.integer(forKey: waitKey))
        guard pid > 0 else { return }
        let deadline = Date.now.addingTimeInterval(10)
        while NSRunningApplication(processIdentifier: pid).map({ !$0.isTerminated }) == true, Date.now < deadline {
            usleep(100_000)
        }
    }
}
