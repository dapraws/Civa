//
//  OviEngineTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation
import SwiftData
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
        // Contact details filled in, so only the tips under test match.
        document.header.email = "darrel@example.com"
        document.header.phone = "+62 812 0000 0000"
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
        #expect(store.record(.fontSize) == nil)
    }

    @Test func openShowsWaving() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        if case .waving(let match) = ovi.state { #expect(match.tip == .fontSize) } else { Issue.record("not waving: \(ovi.state)") }
    }

    /// ✕ snoozes, and Ovi is happy too (2026-11-14): the user dealt with it.
    @Test func closeSnoozesAndShowsHappy() {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.close()
        #expect(ovi.state == .happy)
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
        ovi.contextProvider = { [fine] in fine }  // the action fixed it
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
        #expect(store.record(.fontSize) == nil)
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
        var dates = ResumeDocument.withContact
        dates.format.dateStyle = .numeric
        ovi.visit(OviContext(screen: .resumeEditor(UUID()), resume: dates))
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    /// A new mistake shows without leaving the screen: one tip per visit made you reopen it.
    @Test func nextMistakeShowsInSameVisit() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.close()
        var both = smallFont()
        both.resume?.format.dateStyle = .numeric
        ovi.dataChanged(both)
        await ovi.pendingCheck?.value
        #expect(noticing(ovi)?.tip == .numericDates)
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
        var document = ResumeDocument.withContact
        document.format.fontSize = 9
        OviAction.setFontSize10.apply(to: &document)
        #expect(document.format.fontSize == 10)
    }

    @Test func numericDatesActionSetsShort() {
        var document = ResumeDocument.withContact
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
        // After tailoring, the application may still link the Master; rest instead of asking again at once.
        #expect(!OviScheduler.isEligible(.tailor, store: store, now: now.addingTimeInterval(3600)))
        #expect(store.record(.tailor)?.snoozedUntil == nil)
    }

    @Test func resumeActionGoesThroughTheEditor() throws {
        let container = try ModelContainer.civa(inMemory: true)
        let context = container.mainContext
        var document = ResumeDocument.withContact
        document.format.fontSize = 9
        let resume = Resume(title: "Master", document: document)
        context.insert(resume)
        try context.save()
        let editor = RecordEditor(record: resume, context: context)
        OviAction.setFontSize10.apply(to: editor)
        #expect(editor.isDirty)
        #expect(resume.document.format.fontSize == 10)
    }

    @Test func visitDuringHappyStillChecks() {
        let ovi = OviEngine(store: store, now: { [now] in now }) { duration in
            if duration == OviEngine.happyHold { try await Task.sleep(for: .seconds(3600)) }
        }
        ovi.visit(smallFont())
        ovi.open()
        ovi.took(.setFontSize10)
        var dates = ResumeDocument.withContact
        dates.format.dateStyle = .numeric
        ovi.visit(OviContext(screen: .resumeEditor(UUID()), resume: dates))
        #expect(noticing(ovi)?.tip == .numericDates)
        ovi.pendingHappy?.cancel()
    }

    // MARK: One tip at a time, then the next (2026-11-14)

    private var twoMistakes: OviContext {
        var both = smallFont()
        both.resume?.format.dateStyle = .numeric
        return both
    }

    @Test func closingATipShowsTheNextOneAfterHappy() async {
        let ovi = engine()
        ovi.visit(twoMistakes)
        #expect(noticing(ovi)?.tip == .fontSize)
        ovi.open()
        ovi.close()
        await ovi.pendingHappy?.value
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    @Test func dontShowAgainShowsTheNextOne() {
        let ovi = engine()
        ovi.visit(twoMistakes)
        ovi.open()
        ovi.dontShowAgain()
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    @Test func afterHappyTheNextOneShows() async {
        let ovi = engine()
        ovi.visit(twoMistakes)
        ovi.open()
        ovi.took(.setFontSize10)
        var fixedFont = twoMistakes
        fixedFont.resume?.format.fontSize = 11
        ovi.contextProvider = { fixedFont }
        await ovi.pendingHappy?.value
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    @Test func fixingByHandThenTheNextOneShows() async {
        let ovi = engine()
        ovi.visit(twoMistakes)
        var fixedFont = twoMistakes
        fixedFont.resume?.format.fontSize = 11
        ovi.dataChanged(fixedFont)
        await ovi.pendingCheck?.value
        #expect(store.record(.fontSize)?.lastOutcome == .fixed)
        await ovi.pendingHappy?.value
        #expect(noticing(ovi)?.tip == .numericDates)
    }

    /// A sheet was open at check time; when it closes, Ovi looks again.
    @Test func recheckAfterABlockerClears() {
        let ovi = engine()
        var sheetOpen = true
        ovi.externalBlocker = { sheetOpen }
        ovi.visit(smallFont())
        #expect(ovi.state == .neutral)
        sheetOpen = false
        ovi.recheck()
        #expect(noticing(ovi)?.tip == .fontSize)
    }

    /// Reverting with no tip showing mustn't swallow the Happy of a later fix.
    @Test func discardOnlyCountsWhileATipShows() async {
        let ovi = OviEngine(store: store, now: { [now] in now }) { duration in
            if duration == OviEngine.happyHold { try await Task.sleep(for: .seconds(3600)) }
        }
        ovi.visit(fine)
        ovi.discarded()
        ovi.dataChanged(smallFont())
        await ovi.pendingCheck?.value
        ovi.dataChanged(fine)
        await ovi.pendingCheck?.value
        #expect(ovi.state == .happy)
        ovi.pendingHappy?.cancel()
    }

    /// Taking the action and then reverting it mustn't bring the "!" straight back.
    @Test func revertAfterTheActionRestsTheTip() async {
        let ovi = engine()
        ovi.visit(smallFont())
        ovi.open()
        ovi.took(.setFontSize10)
        ovi.contextProvider = { [fine] in fine }
        await ovi.pendingHappy?.value
        ovi.contextProvider = nil
        ovi.discarded()
        ovi.dataChanged(smallFont())
        await ovi.pendingCheck?.value
        #expect(ovi.state == .neutral)
    }
}

extension ResumeDocument {
    /// A blank resume with an email and phone, so the contact tip stays out of the way.
    static var withContact: ResumeDocument {
        var document = ResumeDocument.blank
        document.header.email = "darrel@example.com"
        document.header.phone = "+62 812 0000 0000"
        return document
    }
}
