//
//  OviEngineTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct OviEngineTests {
    private let store = OviStore(defaults: UserDefaults(suiteName: "OviEngineTests-\(UUID())")!)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Waits finish at once; the tests await the engine's pending work instead of real time.
    private func engine() -> OviEngine {
        OviEngine(store: store, now: { [now] in now }, sleep: { _ in })
    }

    private func smallFont(_ size: Double = 9) -> OviContext {
        var document = ResumeDocument.blank
        document.format.fontSize = size
        return OviContext(screen: .resumeEditor(UUID()), resume: document, resumePageCount: 1)
    }

    private var fine: OviContext { smallFont(11) }

    private func noticing(_ engine: OviEngine) -> OviMatch? {
        if case .noticing(let match) = engine.state { match } else { nil }
    }

    @Test func visitChecksAtOnce() {
        let ovi = engine()
        ovi.visit(smallFont())
        #expect(noticing(ovi)?.tip == .fontSize)
        #expect(store.shownToday(now: now) == 1)
        #expect(store.record(.fontSize)?.lastShown == now)
    }

    @Test func noticesAfterDebounce() async {
        let ovi = engine()
        ovi.visit(fine)
        ovi.dataChanged(smallFont())
        #expect(ovi.state == .neutral)
        await ovi.pendingCheck?.value
        #expect(noticing(ovi)?.tip == .fontSize)
    }

    @Test func debounceRestartsOnChange() async {
        let ovi = engine()
        ovi.visit(fine)
        ovi.dataChanged(smallFont())
        ovi.dataChanged(fine)
        await ovi.pendingCheck?.value
        #expect(ovi.state == .neutral)
        #expect(store.shownToday(now: now) == 0)
    }

    @Test func openShowsWaving() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        if case .waving(let match) = ovi.state { #expect(match.tip == .fontSize) } else { Issue.record("not waving: \(ovi.state)") }
    }

    @Test func closeSnoozesAndReturnsNeutral() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.close()
        #expect(ovi.state == .neutral)
        #expect(store.record(.fontSize)?.snoozedUntil == now.addingTimeInterval(OviScheduler.snooze))
        #expect(store.record(.fontSize)?.lastOutcome == .closed)
    }

    @Test func fixedByHandShowsHappy() async {
        // Happy's hold never ends here, so the test sees Happy.
        let ovi = OviEngine(store: store, now: { [now] in now }) { duration in
            if duration == OviEngine.happyHold { try await Task.sleep(for: .seconds(3600)) }
        }
        ovi.visit(smallFont())
        ovi.dataChanged(fine)
        await ovi.pendingCheck?.value
        #expect(ovi.state == .happy)
        #expect(store.record(.fontSize)?.lastOutcome == .fixed)
        ovi.pendingHappy?.cancel()
    }

    @Test func happySettlesBackToNeutral() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.took(.setFontSize10)
        await ovi.pendingHappy?.value
        #expect(ovi.state == .neutral)
    }

    @Test func discardClosesWithoutHappy() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.discarded()
        ovi.dataChanged(fine)
        await ovi.pendingCheck?.value
        #expect(ovi.state == .neutral)
    }

    @Test func takingTheActionShowsHappyWithoutSnooze() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.took(.setFontSize10)
        #expect(ovi.state == .happy)
        #expect(store.record(.fontSize)?.lastOutcome == .acted)
        #expect(store.record(.fontSize)?.snoozedUntil == nil)
    }

    @Test func blockersPreventNoticing() {
        let ovi = engine()
        ovi.setBlocked(true)
        ovi.visit(smallFont())
        #expect(ovi.state == .neutral)
        #expect(store.shownToday(now: now) == 0)
        ovi.setBlocked(false)
        #expect(noticing(ovi)?.tip == .fontSize)
    }

    @Test func blockerClearsAWaitingTip() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.setBlocked(true)
        #expect(ovi.state == .neutral)
    }

    @Test func newVisitClearsNoticingAndAllowsOneMore() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.visit(fine)
        #expect(ovi.state == .neutral)
        var dates = ResumeDocument.blank
        dates.format.dateStyle = .numeric
        ovi.visit(OviContext(screen: .resumeEditor(UUID()), resume: dates))
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    @Test func oneTipPerVisit() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.close()
        var both = smallFont()
        both.resume?.format.dateStyle = .numeric
        ovi.dataChanged(both)
        await ovi.pendingCheck?.value
        #expect(ovi.state == .neutral)
    }

    @Test func dontShowAgainEndsTheTip() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.dontShowAgain()
        #expect(ovi.state == .neutral)
        #expect(store.record(.fontSize)?.isEnded == true)
    }

    @Test func turnOffHides() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.turnOff()
        #expect(ovi.state == .hidden)
        #expect(store.isShown == false)
        ovi.visit(smallFont())
        #expect(ovi.state == .hidden)
    }

    @Test func fontSizeActionSetsTen() {
        var document = ResumeDocument.blank
        document.format.fontSize = 9
        OviAction.setFontSize10.apply(to: &document)
        #expect(document.format.fontSize == 10)
    }

    @Test func numericDatesActionSetsShort() {
        var document = ResumeDocument.blank
        document.format.dateStyle = .numeric
        OviAction.useShortDates.apply(to: &document)
        #expect(document.format.dateStyle == .short)
    }

    @Test func tailorHandOffClosesWithoutSnooze() {
        let ovi = engine()
        let master = Resume(title: "Master")
        master.isMaster = true
        let application = JobApplication(company: "Stripe", position: "iOS")
        application.resume = master
        ovi.visit(OviContext(screen: .applicationRecord(application.id), application: application))
        ovi.open()
        ovi.handedOff()
        #expect(ovi.state == .neutral)
        #expect(store.record(.tailor)?.lastOutcome == .acted)
        #expect(store.record(.tailor)?.snoozedUntil == nil)
    }
}
