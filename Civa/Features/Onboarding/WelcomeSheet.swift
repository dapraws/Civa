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
        case welcome, gettingStarted, settings
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

/// Shown once, when Civa has no data yet (Flexible Start, PRODUCT.md §12), as three pages: Civa,
/// Ovi, and how to start (tip engine spec §3). Every choice is optional; Esc is Look Around First.
struct WelcomeSheet: View {
    enum Choice {
        case importCV, importLinkedIn, addByHand, lookAround
    }

    let onChoose: (Choice) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    init(onChoose: @escaping (Choice) -> Void) {
        self.onChoose = onChoose
        #if DEBUG
        // Manual checks: -CivaWelcomePage 2 opens on page 2 (counting from 1).
        _page = State(initialValue: max(0, min(2, UserDefaults.standard.integer(forKey: "CivaWelcomePage") - 1)))
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Group {
                switch page {
                case 0: civa
                case 1: ovi
                default: start
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .id(page)
            HStack(spacing: Space.s) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.accent : Color.fieldBorder.opacity(0.5))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Page \(page + 1) of 3"))
                Spacer()
                if page > 0 {
                    Button("Back") { go(page - 1) }
                        .civaButton(.secondary, size: .large)
                }
                if page < 2 {
                    Button("Continue") { go(page + 1) }
                        .keyboardShortcut(.defaultAction)
                        .civaButton(.primary, size: .large)
                }
            }
        }
        .padding(28)
        .frame(width: 520)
        .background(Color.surfaceRaised)
        .onExitCommand { onChoose(.lookAround) }
    }

    private func go(_ next: Int) {
        withAnimation(reduceMotion ? nil : Motion.standard) { page = next }
    }

    // MARK: Pages

    private var civa: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Welcome to Civa").font(.pageTitle).foregroundStyle(Color.textPrimary)
            Text("Your career details in one place on this Mac. Make tailored resumes from them anytime.")
                .foregroundStyle(Color.textSecondary)
            VStack(alignment: .leading, spacing: Space.s) {
                point("person.text.rectangle", "Keep your experience, education, and projects in one Career Profile.")
                point("doc.on.doc", "Build many resumes from it, each tailored to a job.")
                point("lock", "Everything stays on this Mac. No account needed.")
            }
            .padding(.top, Space.xs)
        }
    }

    private var ovi: some View {
        VStack(spacing: Space.m) {
            Image("Ovi/Front")
                .resizable()
                .scaledToFit()
                .frame(height: 128)
                .accessibilityLabel("Ovi, Civa's guide")
            VStack(alignment: .leading, spacing: Space.s) {
                Text("This is Ovi").font(.pageTitle).foregroundStyle(Color.textPrimary)
                Text("Ovi sits at the bottom of the sidebar. While you work, Ovi points out resume facts people often miss, from career offices like MIT's.")
                    .foregroundStyle(Color.textSecondary)
                Text("When Ovi spots something, a ! appears. Click Ovi to read the tip. Ovi never interrupts your typing, and you can turn Ovi off anytime.")
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("How do you want to start?").font(.pageTitle).foregroundStyle(Color.textPrimary)
            VStack(spacing: Space.s) {
                row(.importCV, "doc.text", "Import a CV or LinkedIn PDF", "Civa reads it and lets you check everything before saving.")
                row(.importLinkedIn, "archivebox", "Import a LinkedIn Data Export", "The ZIP from LinkedIn’s Settings & Privacy → Data Privacy.")
                row(.addByHand, "square.and.pencil", "Add by Hand", "Start with your name and contact details.")
                row(.lookAround, "eye", "Look Around First", "Close this and explore. Help → Show Welcome brings it back.")
            }
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Color.claude).accessibilityHidden(true)
                Text("Use Claude Desktop? You can connect it later from the Dashboard or Settings.")
                    .foregroundStyle(Color.textSecondary)
            }
            .font(.callout)
        }
    }

    private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: symbol).foregroundStyle(Color.accent).frame(width: 18).accessibilityHidden(true)
            Text(text).foregroundStyle(Color.textPrimary)
        }
    }

    private func row(_ choice: Choice, _ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        Button {
            onChoose(choice)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accent)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodyEmphasis).foregroundStyle(Color.textPrimary)
                    Text(detail).foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary).accessibilityHidden(true)
            }
            .padding(12)
            .contentShape(.rect)
            .background(Color.surface, in: .rect(cornerRadius: Radius.card))
            .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeSheet { _ in }
}
