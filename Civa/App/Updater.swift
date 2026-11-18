//
//  Updater.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Sparkle
import SwiftUI

/// Civa's updates, through Sparkle: it reads the appcast at `SUFeedURL`, checks each update's
/// signature against `SUPublicEDKey`, shows the release notes, and installs when the user says so.
/// Debug builds never check.
@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observation: NSKeyValueObservation?
    /// False while a check is already running.
    private(set) var canCheck = false
    /// Settings → Updates: check in the background about once a day.
    var checksAutomatically: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    private init() {
        #if DEBUG
        let starts = false
        #else
        let starts = true
        #endif
        controller = SPUStandardUpdaterController(startingUpdater: starts, updaterDelegate: nil, userDriverDelegate: nil)
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheck = canCheck }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Civa → Check for Updates….
struct CheckForUpdatesCommand: View {
    private let updater = Updater.shared

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!updater.canCheck)
    }
}

/// Settings → Updates.
struct UpdatesSection: View {
    @Bindable private var updater = Updater.shared

    var body: some View {
        Section {
            Toggle("Check for Updates Automatically", isOn: $updater.checksAutomatically)
            LabeledContent("Version \(Bundle.main.shortVersion)") {
                Button("Check Now", action: updater.checkForUpdates)
                    .civaButton(.textLink)
                    .disabled(!updater.canCheck)
            }
        } header: {
            SectionTitle("Updates")
        } footer: {
            Text("Civa checks about once a day and asks before installing. Only Civa's version is sent.")
        }
    }
}

extension Bundle {
    /// "1.1.0".
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

#Preview {
    Form { UpdatesSection() }.civaForm()
}
