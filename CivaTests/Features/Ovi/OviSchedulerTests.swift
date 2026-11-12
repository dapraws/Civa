//
//  OviSchedulerTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct OviSchedulerTests {
    private let defaults = UserDefaults(suiteName: "OviTests-\(UUID())")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }
    private var store: OviStore { OviStore(defaults: defaults, calendar: calendar) }

    private func date(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    private func match(_ tip: OviTipID) -> OviMatch {
        OviMatch(tip: tip, title: "t", body: "b", source: "s")
    }

    private let noon = "2026-11-12T05:00:00Z"  // 12:00 in Jakarta

    @Test func endedTipNeverReturns() {
        store.update(.addNumber) { $0.isEnded = true }
        #expect(!OviScheduler.isEligible(.addNumber, store: store, now: date(noon)))
    }

    @Test func onceEverTipShowsOnce() {
        let now = date(noon)
        #expect(OviScheduler.isEligible(.pageCount, store: store, now: now))
        store.update(.pageCount) { $0.lastShown = now }
        #expect(!OviScheduler.isEligible(.pageCount, store: store, now: now.addingTimeInterval(30 * 86_400)))
    }

    @Test func closeSnoozes14Days() {
        let now = date(noon)
        store.update(.addNumber) { $0.lastShown = now; $0.snoozedUntil = now.addingTimeInterval(OviScheduler.snooze); $0.lastOutcome = .closed }
        #expect(!OviScheduler.isEligible(.addNumber, store: store, now: now.addingTimeInterval(13 * 86_400)))
        #expect(OviScheduler.isEligible(.addNumber, store: store, now: now.addingTimeInterval(14 * 86_400)))
    }

    @Test func unopenedTipRests24Hours() {
        let now = date(noon)
        store.update(.addNumber) { $0.lastShown = now; $0.lastOutcome = .shown }
        #expect(!OviScheduler.isEligible(.addNumber, store: store, now: now.addingTimeInterval(23 * 3600)))
        #expect(OviScheduler.isEligible(.addNumber, store: store, now: now.addingTimeInterval(24 * 3600)))
    }

    @Test func actionNeverSnoozes() {
        let now = date(noon)
        store.update(.fontSize) { $0.lastShown = now; $0.lastOutcome = .acted }
        #expect(OviScheduler.isEligible(.fontSize, store: store, now: now.addingTimeInterval(60)))
    }

    @Test func visitLimitIsOne() {
        let picked = OviScheduler.pick([match(.fontSize)], store: store, now: date(noon), visitHasShown: true)
        #expect(picked == nil)
    }

    @Test func pickSkipsIneligibleAndKeepsPriority() {
        store.update(.fontSize) { $0.isEnded = true }
        let picked = OviScheduler.pick([match(.fontSize), match(.numericDates)], store: store, now: date(noon), visitHasShown: false)
        #expect(picked?.tip == .numericDates)
    }

    @Test func dailyCapIsThree() {
        let now = date(noon)
        for _ in 0..<3 { store.countShown(now: now) }
        #expect(store.shownToday(now: now) == 3)
        #expect(OviScheduler.pick([match(.fontSize)], store: store, now: now, visitHasShown: false) == nil)
    }

    @Test func dailyCapResetsAtMidnight() {
        let beforeMidnight = date("2026-11-12T16:59:00Z")  // 23:59 in Jakarta
        let afterMidnight = date("2026-11-12T17:01:00Z")   // 00:01 next day
        for _ in 0..<3 { store.countShown(now: beforeMidnight) }
        #expect(store.shownToday(now: afterMidnight) == 0)
        #expect(OviScheduler.pick([match(.fontSize)], store: store, now: afterMidnight, visitHasShown: false)?.tip == .fontSize)
    }

    @Test func unknownAndCorruptStateIsIgnored() {
        defaults.set(Data(#"{"retiredTip":{"isEnded":true,"lastOutcome":"closed"}}"#.utf8), forKey: OviStore.tipStateKey)
        #expect(OviScheduler.isEligible(.fontSize, store: store, now: date(noon)))
        defaults.set(Data("not json".utf8), forKey: OviStore.tipStateKey)
        #expect(OviScheduler.isEligible(.fontSize, store: store, now: date(noon)))
        store.update(.fontSize) { $0.isEnded = true }
        #expect(!OviScheduler.isEligible(.fontSize, store: store, now: date(noon)))
    }

    @Test func resetKeepsShowOvi() {
        store.isShown = false
        store.update(.fontSize) { $0.isEnded = true }
        store.countShown(now: date(noon))
        store.reset()
        #expect(store.isShown == false)
        #expect(store.record(.fontSize) == nil)
        #expect(store.shownToday(now: date(noon)) == 0)
    }

    @Test func showOviDefaultsToOn() {
        #expect(store.isShown)
    }
}
