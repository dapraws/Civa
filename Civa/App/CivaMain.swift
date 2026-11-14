//
//  CivaMain.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Starts the app, or the Claude Desktop helper when launched with `--mcp`.
@main
enum CivaMain {
    static func main() {
        AppRelauncher.waitForPreviousInstance()
        if CommandLine.arguments.contains(ClaudeLink.helperArgument) {
            ClaudeHelper.run()
        } else {
            // First, so a switch asked for before the restart swaps the workspace's preferences
            // before Ovi, tips, or Claude's permissions read them.
            _ = WorkspaceRegistry.shared
            CivaApp.main()
        }
    }
}
