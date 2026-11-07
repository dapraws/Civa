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
        if CommandLine.arguments.contains(ClaudeLink.helperArgument) {
            ClaudeHelper.run()
        } else {
            CivaApp.main()
        }
    }
}
