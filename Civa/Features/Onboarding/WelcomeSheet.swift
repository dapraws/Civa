//
//  WelcomeSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Observation
import SwiftUI

/// First-run help: the welcome sheet and the Getting Started card, reopened from the Help menu.
@Observable
final class Onboarding {
    static let shared = Onboarding()
    static let welcomeShownKey = "WelcomeShown"
    static let checklistHiddenKey = "GettingStartedHidden"

    enum Request {
        case welcome, gettingStarted
    }

    /// Set by the Help menu; RootView goes to the Dashboard first, then shows it.
    var request: Request?
    var showsWelcome = false
    /// An import picked on the welcome sheet; the Import menu on screen opens its file panel.
    var importKind: ImportRequest.Kind?

    init() {
        #if DEBUG
        // Manual checks: -CivaShowWelcome YES
        showsWelcome = UserDefaults.standard.bool(forKey: "CivaShowWelcome")
        #endif
    }
}

/// Shown once, when Civa has no data yet (Flexible Start, PRODUCT.md §12). Every choice is
/// optional; Look Around just closes it.
struct WelcomeSheet: View {
    enum Choice {
        case importCV, importLinkedIn, addByHand, lookAround
    }

    let onChoose: (Choice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Civa").font(.largeTitle.weight(.semibold))
                Text("Your career details in one place on this Mac. Make tailored resumes from them anytime.")
                    .foregroundStyle(.secondary)
            }
            Text("How do you want to start?").font(.headline)
            VStack(spacing: 8) {
                row(.importCV, "doc.text", "Import a CV or LinkedIn PDF", "Civa reads it and lets you check everything before saving.")
                row(.importLinkedIn, "archivebox", "Import a LinkedIn Data Export", "The ZIP from LinkedIn’s Settings & Privacy → Data Privacy.")
                row(.addByHand, "square.and.pencil", "Add by Hand", "Start with your name and contact details.")
                row(.lookAround, "eye", "Look Around First", "Close this and explore. Help → Show Welcome brings it back.")
            }
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.claude).accessibilityHidden(true)
                Text("Use Claude Desktop? You can connect it later from the Dashboard or Settings.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(28)
        .frame(width: 520)
    }

    private func row(_ choice: Choice, _ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        Button {
            onChoose(choice)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(12)
            .contentShape(.rect)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeSheet { _ in }
}
