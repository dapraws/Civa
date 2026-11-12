//
//  OviScheduler.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation

/// Which tip, if any, may show now (tip engine spec §5.2–§5.5).
enum OviScheduler {
    static let dailyCap = 3
    /// ✕ quiets a tip for 14 days.
    static let snooze: TimeInterval = 14 * 86_400
    /// A "!" left without ✕ or an action rests for 24 hours, so walking between screens doesn't replay it.
    static let rest: TimeInterval = 86_400

    static func isEligible(_ id: OviTipID, store: OviStore, now: Date) -> Bool {
        guard let record = store.record(id) else { return true }
        if record.isEnded { return false }
        if id.isOnceEver, record.lastShown != nil { return false }
        if let until = record.snoozedUntil, now < until { return false }
        if record.lastOutcome == .shown, let shown = record.lastShown, now.timeIntervalSince(shown) < rest { return false }
        return true
    }

    /// The highest-priority eligible match, unless this visit already showed one or today's cap is reached.
    static func pick(_ matches: [OviMatch], store: OviStore, now: Date, visitHasShown: Bool) -> OviMatch? {
        guard !visitHasShown, store.shownToday(now: now) < dailyCap else { return nil }
        return matches.first { isEligible($0.tip, store: store, now: now) }
    }
}
