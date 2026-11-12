//
//  OviEngine.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation
import Observation

/// Ovi's state on the perch (DESIGN.md §9.3, tip engine spec §5). Ovi never opens a bubble by
/// itself: it notices ("!"), and the bubble opens only when the user clicks Ovi.
@Observable
final class OviEngine {
    enum State: Equatable {
        case hidden
        case neutral
        /// A tip is waiting: the "!" shows.
        case noticing(OviMatch)
        /// The bubble is open: Ovi talks.
        case waving(OviMatch)
        case happy
    }

    static let debounce = Duration.milliseconds(1500)
    static let happyHold = Duration.milliseconds(1200)

    private(set) var state: State

    private let store: OviStore
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private var context: OviContext?
    private var visitHasShown = false
    private var isBlocked = false
    private var wasDiscarded = false
    /// Checked with every check: an open sheet or marked (IME) text. Set by the app.
    var externalBlocker: () -> Bool = { false }

    /// The debounced check after a change, awaited by tests.
    private(set) var pendingCheck: Task<Void, Never>?
    /// Happy's hold before Ovi settles back, awaited by tests.
    private(set) var pendingHappy: Task<Void, Never>?

    init(
        store: OviStore = OviStore(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.now = now
        self.sleep = sleep
        state = store.isShown ? .neutral : .hidden
    }

    // MARK: Inputs

    /// A new screen or record: one tip per visit, checked at once.
    func visit(_ context: OviContext?) {
        pendingCheck?.cancel()
        self.context = context
        visitHasShown = false
        wasDiscarded = false
        if case .noticing = state { state = .neutral }
        if case .waving = state { state = .neutral }
        check()
    }

    /// The data on screen changed; checks 1.5 s after the last change, never mid-keystroke.
    func dataChanged(_ context: OviContext?) {
        self.context = context
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self, sleep] in
            do { try await sleep(Self.debounce) } catch { return }
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    /// A sheet, drag, collapsed sidebar, marked text or TipKit tip: no "!" until it clears.
    func setBlocked(_ blocked: Bool) {
        isBlocked = blocked
        if blocked, case .noticing = state { state = .neutral }
        if !blocked { check() }
    }

    /// Edits were discarded: if that clears the tip, close without Happy.
    func discarded() {
        wasDiscarded = true
    }

    /// "Show Ovi" may have changed (Settings).
    func refresh() {
        if !store.isShown {
            state = .hidden
        } else if state == .hidden {
            state = .neutral
            check()
        }
    }

    // MARK: The user

    func open() {
        if case .noticing(let match) = state { state = .waving(match) }
    }

    /// ✕: quiet this tip for 14 days.
    func close() {
        guard let match = current else { return }
        store.update(match.tip) {
            $0.snoozedUntil = now().addingTimeInterval(OviScheduler.snooze)
            $0.lastOutcome = .closed
        }
        state = .neutral
    }

    /// The bubble's action was taken (the caller applied it). Never snoozes.
    func took(_ action: OviAction) {
        guard let match = current else { return }
        store.update(match.tip) { $0.lastOutcome = .acted }
        showHappy()
    }

    /// The action continues elsewhere (the Tailor sheet): close without snooze or Happy.
    func handedOff() {
        guard let match = current else { return }
        store.update(match.tip) { $0.lastOutcome = .acted }
        state = .neutral
    }

    func dontShowAgain() {
        guard let match = current else { return }
        store.update(match.tip) { $0.isEnded = true }
        state = .neutral
    }

    func turnOff() {
        store.isShown = false
        state = .hidden
    }

    /// The tip on screen, while the "!" or the bubble shows.
    var current: OviMatch? {
        switch state {
        case .noticing(let match), .waving(let match): match
        default: nil
        }
    }

    #if DEBUG
    /// Manual checks and screenshots: -CivaOviPreview fontSize shows that tip's "!",
    /// and -CivaOviOpen YES opens its bubble.
    func showPreview(_ tip: OviTipID, open: Bool) {
        guard let match = OviRules.longestVariants.first(where: { $0.tip == tip }) else { return }
        state = open ? .waving(match) : .noticing(match)
    }
    #endif

    // MARK: Checking (spec §5)

    private func check() {
        guard store.isShown else { return state = .hidden }
        let matches = context.map(OviRules.matches(in:)) ?? []
        if let shown = current {
            if let updated = matches.first(where: { $0.tip == shown.tip }) {
                // Keep the copy current, such as a new font size.
                state = state == .waving(shown) ? .waving(updated) : .noticing(updated)
            } else if wasDiscarded {
                wasDiscarded = false
                state = .neutral
            } else {
                store.update(shown.tip) { $0.lastOutcome = .fixed }
                showHappy()
            }
            return
        }
        guard state == .neutral, !isBlocked, !externalBlocker(),
              let pick = OviScheduler.pick(matches, store: store, now: now(), visitHasShown: visitHasShown)
        else { return }
        visitHasShown = true
        store.update(pick.tip) {
            $0.lastShown = now()
            $0.lastOutcome = .shown
        }
        store.countShown(now: now())
        state = .noticing(pick)
    }

    private func showHappy() {
        state = .happy
        pendingHappy?.cancel()
        pendingHappy = Task { [weak self, sleep] in
            do { try await sleep(Self.happyHold) } catch { return }
            guard let self, self.state == .happy else { return }
            self.state = .neutral
        }
    }
}
