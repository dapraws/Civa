//
//  ClaudeRequestNotice.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Observation
import SwiftUI
import UserNotifications

/// Says a request is waiting for Claude: a macOS notification when allowed, otherwise a banner
/// in Civa. Clicking either opens AI Activity → Requests, where "Open Claude" starts it.
@Observable
final class ClaudeRequestNotice: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ClaudeRequestNotice()

    /// The in-app banner's request title, while it shows.
    var banner: String?
    /// Set when a notice is clicked; RootView goes to Requests and clears it.
    var opensRequests = false

    @ObservationIgnored private var bannerCount = 0

    /// Call at launch, so clicks on notifications from an earlier run reach Civa too.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        // Show the banner for manual checks: -CivaShowRequestBanner YES
        if UserDefaults.standard.bool(forKey: "CivaShowRequestBanner") { banner = "Write a summary for “Master Resume”" }
        #endif
    }

    static func content(for title: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Civa Has a Request for Claude")
        content.body = title
        content.threadIdentifier = "claude-requests"
        return content
    }

    /// Asks for permission the first time; falls back to the banner when notifications are off.
    func post(_ title: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            var allowed = await center.notificationSettings().authorizationStatus
            if allowed == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                allowed = await center.notificationSettings().authorizationStatus
            }
            guard allowed == .authorized || allowed == .provisional else { return showBanner(title) }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: Self.content(for: title), trigger: nil)
            do {
                try await center.add(request)
            } catch {
                showBanner(title)
            }
        }
    }

    func open() {
        banner = nil
        opensRequests = true
    }

    /// Hides itself after 6 seconds unless a newer request replaced it.
    private func showBanner(_ title: String) {
        banner = title
        bannerCount += 1
        let count = bannerCount
        Task {
            try? await Task.sleep(for: .seconds(6))
            if bannerCount == count { banner = nil }
        }
    }

    // The user is always in Civa when they ask, so show the notification in front of it too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { open() }
    }
}

/// The banner shown at the top of the window when notifications are off.
struct ClaudeRequestBanner: View {
    let title: String
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.claude)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Civa Has a Request for Claude").font(.headline)
                Text(title).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            Button("View Request", action: onOpen)
                .buttonStyle(.borderedProminent)
                .tint(.claude)
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: 520)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.claude.opacity(0.4)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

#Preview {
    ClaudeRequestBanner(title: "Write a summary for “Master Resume”", onOpen: {}, onClose: {})
        .padding(40)
}
