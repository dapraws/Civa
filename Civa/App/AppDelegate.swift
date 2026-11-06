//
//  AppDelegate.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let changes = UnsavedChangesGuard()

    /// Civa is a single window, so closing it quits, which goes through the guard below.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Quitting is navigation too: ask before unsaved edits disappear.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let active = changes.active, active.isDirty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = String(localized: "Do you want to save the changes to “\(active.title)”?")
        alert.informativeText = String(localized: "Your changes will be lost if you don't save them.")
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Don't Save")).hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn: return active.save() ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn: return .terminateNow
        default: return .terminateCancel
        }
    }
}
