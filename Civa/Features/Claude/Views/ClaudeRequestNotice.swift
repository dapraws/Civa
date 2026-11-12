//
//  ClaudeRequestNotice.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Observation
import SwiftUI

/// Says a request is waiting for Claude with a banner in Civa; no notification permission needed.
/// Clicking it opens AI Activity → Requests, where "Open Claude" starts it.
@Observable
final class ClaudeRequestNotice {
    static let shared = ClaudeRequestNotice()

    /// The banner's request title, while it shows.
    var banner: String?
    /// Set when the banner is clicked; RootView goes to Requests and clears it.
    var opensRequests = false

    @ObservationIgnored private var bannerCount = 0

    init() {
        #if DEBUG
        // Show the banner for manual checks: -CivaShowRequestBanner YES
        if UserDefaults.standard.bool(forKey: "CivaShowRequestBanner") { banner = "Write a summary for “Master Resume”" }
        #endif
    }

    /// Shows the banner; it hides itself after 6 seconds unless a newer request replaced it.
    func post(_ title: String) {
        banner = title
        bannerCount += 1
        let count = bannerCount
        Task {
            try? await Task.sleep(for: .seconds(6))
            if bannerCount == count { banner = nil }
        }
    }

    func open() {
        banner = nil
        opensRequests = true
    }
}

/// The banner shown at the top of the window after a request is queued.
struct ClaudeRequestBanner: View {
    let title: String
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        CivaBanner(
            message: String(localized: "Civa has a request for Claude: \(title)"),
            isClaude: true,
            actionTitle: "View Request",
            action: onOpen,
            onClose: onClose
        )
    }
}

#Preview {
    ClaudeRequestBanner(title: "Write a summary for “Master Resume”", onOpen: {}, onClose: {})
        .padding(40)
}
