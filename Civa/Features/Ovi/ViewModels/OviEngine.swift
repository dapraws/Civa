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
    private var isBlocked = false
    private var wasDiscarded = false
    /// The tip whose action was just taken: Revert undoes the action, so the tip rests then.
    private var lastActed: OviTipID?
    /// Checked with every check: an open sheet or marked (IME) text. Set by the app.
    var externalBlocker: () -> Bool = { false }
    /// Builds the full context at check time (the resume's page count needs a PDF render), so it
    /// runs after the debounce, not on every keystroke. Set by the app; tests pass contexts.
    var contextProvider: (() -> OviContext?)?

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

    /// A new screen or record, checked at once.
    func visit(_ context: OviContext?) {
        pendingCheck?.cancel()
        self.context = context
        wasDiscarded = false
        if case .noticing = state { state = .neutral }
        if case .waving = state { state = .neutral }
        if state == .happy {
            pendingHappy?.cancel()
            state = .neutral
        }
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

    /// Edits were discarded: if that clears the tip showing now, close without Happy. With no tip
    /// showing there's nothing to close, so a later fix still gets its Happy.
    func discarded() {
        wasDiscarded = current != nil
        // Reverting the change a tip's action made would bring the "!" straight back; let it rest.
        if current == nil, let tip = lastActed {
            store.update(tip) {
                $0.lastShown = now()
                $0.lastOutcome = .shown
            }
        }
        lastActed = nil
    }

    /// Looks again now, such as when a sheet that was blocking the "!" closes.
    func recheck() {
        check()
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

    /// ✕: quiet this tip for 14 days. Ovi is happy too: the user dealt with it.
    func close() {
        guard let match = current else { return }
        store.update(match.tip) {
            $0.snoozedUntil = now().addingTimeInterval(OviScheduler.snooze)
            $0.lastOutcome = .closed
        }
        // Then the next tip on this screen, after Happy.
        showHappy()
    }

    /// The bubble's action was taken (the caller applied it). Never snoozes.
    func took(_ action: OviAction) {
        guard let match = current else { return }
        store.update(match.tip) { $0.lastOutcome = .acted }
        lastActed = match.tip
        showHappy()
    }

    /// The action continues elsewhere (the Tailor sheet): close without snooze or Happy, and rest
    /// for a day, since the application may still link the Master after tailoring.
    func handedOff() {
        guard let match = current else { return }
        store.update(match.tip) {
            $0.lastShown = now()
            $0.lastOutcome = .shown
        }
        state = .neutral
        check()
    }

    func dontShowAgain() {
        guard let match = current else { return }
        store.update(match.tip) { $0.isEnded = true }
        state = .neutral
        check()
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
        let matches = (contextProvider?() ?? context).map(OviRules.matches(in:)) ?? []
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
              let pick = OviScheduler.pick(matches, store: store, now: now())
        else { return }
        store.update(pick.tip) {
            $0.lastShown = now()
            $0.lastOutcome = .shown
        }
        state = .noticing(pick)
    }

    private func showHappy() {
        state = .happy
        pendingHappy?.cancel()
        pendingHappy = Task { [weak self, sleep] in
            do { try await sleep(Self.happyHold) } catch { return }
            guard let self, self.state == .happy else { return }
            self.state = .neutral
            self.check()
        }
    }
}
