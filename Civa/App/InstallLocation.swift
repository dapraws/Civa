//
//  InstallLocation.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 18/11/26.
//

import AppKit

/// Asks people who opened Civa straight from the disk image to put it in Applications first.
/// Civa is sandboxed, so it can't move itself: it opens the Applications folder instead.
enum InstallLocation {
    /// True when Civa runs from a mounted disk image, or from a translocated copy (an app opened
    /// from Downloads or the disk image before it was moved).
    nonisolated static func needsMove(bundlePath: String) -> Bool {
        bundlePath.hasPrefix("/Volumes/") || bundlePath.contains("/AppTranslocation/")
    }

    static func promptIfNeeded() {
        #if !DEBUG
        guard needsMove(bundlePath: Bundle.main.bundlePath) else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Move Civa to Applications")
        alert.informativeText = String(localized: "You opened Civa from the disk image. Drag it into your Applications folder so it's still there after you eject the disk, then open it from there.")
        alert.addButton(withTitle: String(localized: "Open Applications Folder"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(filePath: "/Applications", directoryHint: .isDirectory))
        }
        #endif
    }
}
