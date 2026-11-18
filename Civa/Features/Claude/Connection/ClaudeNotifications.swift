//
//  ClaudeNotifications.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import AppKit
import UserNotifications

/// A macOS notification when Claude sends Civa something to review while Civa is in the
/// background, so it doesn't wait unseen. macOS asks the user once whether to allow them.
enum ClaudeNotifications {
    /// What each write tool sent, as a notification says it; nil for tools that send nothing to review.
    static func message(for tool: String) -> String? {
        switch tool {
        case "suggest_resume_edit": String(localized: "Claude suggested changes to a resume.")
        case "suggest_profile_edit": String(localized: "Claude suggested a change to your Career Profile.")
        case "create_resume_draft": String(localized: "Claude drafted a resume for you.")
        case "suggest_profile_records": String(localized: "Claude sent records to add to your Career Profile.")
        default: nil
        }
    }

    @MainActor
    static func post(after request: ClaudeLink.Request, _ reply: ClaudeLink.Reply) {
        guard reply.ok, !NSApp.isActive, let body = message(for: request.tool) else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Waiting in Review")
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
