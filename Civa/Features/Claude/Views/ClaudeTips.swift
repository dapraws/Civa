//
//  ClaudeTips.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import TipKit

/// A one-time pointer at a Claude button, shown only once Claude Desktop is set up. Using the
/// button or closing the tip dismisses it for good.
struct ClaudeTip: Tip {
    /// Mirrors `ClaudeBridge.isEnabled`.
    @Parameter static var isConnected: Bool = false

    let id: String
    let titleText: LocalizedStringResource
    let messageText: LocalizedStringResource

    var title: Text { Text(titleText).foregroundStyle(.claude) }
    var message: Text? { Text(messageText) }
    var image: Image? { Image(systemName: "sparkles") }
    var rules: [Rule] { [#Rule(Self.$isConnected) { $0 == true }] }

    static let askResume = ClaudeTip(
        id: "claude.askResume",
        titleText: "Ask Claude about this resume",
        messageText: "Claude can write a summary or tailor a copy to a job. You review every change here."
    )
    static let improve = ClaudeTip(
        id: "claude.improve",
        titleText: "Improve with Claude",
        messageText: "Claude rewrites these bullets in a few versions; you pick one or keep yours."
    )
    static let draft = ClaudeTip(
        id: "claude.draft",
        titleText: "Draft a resume with Claude",
        messageText: "Claude builds a resume for this job from your confirmed Career Profile."
    )

    /// Call once at launch.
    static func configure() {
        #if DEBUG
        // Manual checks: -CivaResetTips YES, or the Empty data mode, shows every tip again.
        if UserDefaults.standard.bool(forKey: "CivaResetTips") || DataMode.current == .empty { try? Tips.resetDatastore() }
        #endif
        try? Tips.configure()
    }
}
