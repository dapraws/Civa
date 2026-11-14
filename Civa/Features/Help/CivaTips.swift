//
//  CivaTips.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import TipKit

/// One-time pointers at features that are easy to miss. Closing a tip dismisses it for good;
/// Help → Civa Help → Show All Tips Again brings every tip back.
struct CivaTip: Tip {
    let id: String
    let titleText: LocalizedStringResource
    let messageText: LocalizedStringResource
    let symbol: String

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }
    var image: Image? { Image(systemName: symbol) }

    static let ribbon = CivaTip(
        id: "civa.ribbon",
        titleText: "Format the whole resume here",
        messageText: "Pick a template, font, and spacing. Turn on Guides to see each distance on the page.",
        symbol: "ruler"
    )
    static let proof = CivaTip(
        id: "civa.proof",
        titleText: "Proof Check",
        messageText: "Entries with a proof link get a small check after the title, and the title opens the link from the PDF. Turn it off here for the whole resume.",
        symbol: "checkmark.seal"
    )
    static let eye = CivaTip(
        id: "civa.eye",
        titleText: "Hide without deleting",
        messageText: "The eye hides a detail on this resume and keeps what you typed, so you can bring it back anytime.",
        symbol: "eye"
    )
    static let skills = CivaTip(
        id: "civa.skills",
        titleText: "Your categories, your names",
        messageText: "Group skills however you like, such as Hard Skills, Soft Skills, or Tools. Drag a skill onto a category to move it.",
        symbol: "tag"
    )
}

/// Tip setup for the whole app.
enum CivaTips {
    /// Set by Show All Tips Again; TipKit can only be reset before it starts.
    static let resetKey = "ResetTipsOnLaunch"

    /// Call once at launch.
    static func configure() {
        var resets = UserDefaults.standard.bool(forKey: resetKey)
        #if DEBUG
        // Manual checks: -CivaResetTips YES, or the Empty data mode, shows every tip again.
        resets = resets || UserDefaults.standard.bool(forKey: "CivaResetTips") || DataMode.current == .empty
        #endif
        #if DEBUG
        // -CivaResetOvi YES, or the Empty data mode, shows Ovi's tips again (tip engine spec §6).
        if UserDefaults.standard.bool(forKey: "CivaResetOvi") || DataMode.current == .empty {
            OviStore().reset()
        }
        #endif
        // Each workspace remembers its own tips; the first keeps TipKit's usual place.
        #if DEBUG
        let usesWorkspace = DataMode.current == .real
        #else
        let usesWorkspace = true
        #endif
        let workspaces = WorkspaceRegistry.shared
        let folder = usesWorkspace ? workspaces.tipsURL(for: workspaces.current) : nil
        if resets {
            // resetDatastore() only clears TipKit's usual place, so a workspace's own folder is emptied here.
            if let folder { try? FileManager.default.removeItem(at: folder) } else { try? Tips.resetDatastore() }
            UserDefaults.standard.removeObject(forKey: resetKey)
        }
        var options: [Tips.ConfigurationOption] = []
        if let folder {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            options.append(.datastoreLocation(.url(folder)))
        }
        try? Tips.configure(options)
    }
}
