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

    // Tip requirements are nonisolated; the generated asset symbols are main-actor, so name the set.
    var title: Text { Text(titleText).foregroundStyle(Color("claudeText")) }
    var message: Text? { Text(messageText) }
    /// Popover tips ignore `tipImageStyle` and draw the image in the accent blue, so the spark
    /// carries its own clay color.
    var image: Image? {
        guard let spark = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil),
              let clay = NSColor(named: "claude"),
              let colored = spark.withSymbolConfiguration(.init(paletteColors: [clay])) else {
            return Image(systemName: "sparkles")
        }
        return Image(nsImage: colored).renderingMode(.original)
    }
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
}
