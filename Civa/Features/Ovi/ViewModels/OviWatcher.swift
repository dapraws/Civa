//
//  OviWatcher.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import AppKit
import PDFKit
import SwiftData
import SwiftUI

/// Builds what Ovi's rules read from the screen the user is on (tip engine spec §4.1).
enum OviContextBuilder {
    /// The context, plus a signature of everything the rules read, which changes with any edit.
    /// `full: false` skips the costly parts (the PDF page count, education levels, years), for
    /// the per-keystroke signature; the engine builds the full context only when it checks.
    static func make(navigation: AppNavigation, in context: ModelContext, isNewRecord: Bool, full: Bool = true) -> (context: OviContext, signature: Int)? {
        var hasher = Hasher()
        hasher.combine(isNewRecord)
        let built: OviContext?
        switch navigation.section {
        case .careerProfile:
            switch navigation.profileCategory {
            case .professional, .organizational:
                guard let id = navigation.openRecordID,
                      let record = fetch(Experience.self, #Predicate { $0.id == id }, in: context).first
                else { return nil }
                hasher.combine(record.location)
                hasher.combine(record.start)
                hasher.combine(record.impacts)
                hasher.combine(record.isCurrent)
                hasher.combine(navigation.justSavedRecordID == id)
                built = OviContext(
                    screen: .experienceRecord(id),
                    experience: record,
                    justSavedNewCurrentExperience: navigation.justSavedRecordID == id
                )
            case .projects:
                guard let id = navigation.openRecordID,
                      let record = fetch(Project.self, #Predicate { $0.id == id }, in: context).first
                else { return nil }
                hasher.combine(record.impacts)
                built = OviContext(screen: .projectRecord(id), project: record)
            case .other where navigation.isOnSkills:
                let skills = fetch(Skill.self, nil, in: context)
                hasher.combine(skills.map(\.category))
                built = OviContext(screen: .skills, skills: skills)
            default:
                built = nil
            }
        case .resumes:
            guard let id = navigation.openRecordID,
                  let resume = fetch(Resume.self, #Predicate { $0.id == id }, in: context).first
            else { return nil }
            let document = resume.document
            hasher.combine(document)
            let justExported = navigation.justExportedResumeID == id
            hasher.combine(justExported)
            guard full else {
                built = OviContext(screen: .resumeEditor(id), resume: document)
                break
            }
            let levels = Dictionary(
                fetch(Education.self, nil, in: context).compactMap { education in education.degreeLevel.map { (education.id, $0) } },
                uniquingKeysWith: { first, _ in first }
            )
            // Rendered only when the engine checks (after the 1.5 s debounce), not per keystroke.
            let pages = PDFDocument(data: ResumeRenderer.pdf(for: document))?.pageCount ?? 1
            let experiences = fetch(Experience.self, nil, in: context)
            var resumeContext = OviContext(
                screen: .resumeEditor(id),
                resume: document,
                resumePageCount: pages,
                educationLevels: levels,
                yearsOfExperience: yearsOfExperience(experiences)
            )
            resumeContext.largestGapMonths = largestGapMonths(experiences)
            resumeContext.justExported = justExported
            built = resumeContext
        case .applications:
            guard let id = navigation.openRecordID,
                  let application = fetch(JobApplication.self, #Predicate { $0.id == id }, in: context).first
            else { return nil }
            hasher.combine(application.resume?.id)
            hasher.combine(application.resume?.isMaster)
            var applicationContext = OviContext(screen: .applicationRecord(id), application: application)
            if full, let resumeID = application.resume?.id {
                let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
                applicationContext.applicationsWithSameResumeThisWeek = fetch(
                    JobApplication.self, #Predicate { $0.createdAt >= weekAgo }, in: context
                ).filter { $0.resume?.id == resumeID }.count
            }
            built = applicationContext
        default:
            built = nil
        }
        guard var built else { return nil }
        built.isNewRecord = isNewRecord
        return (built, hasher.finalize())
    }

    /// The longest stretch, in months, between the end of one professional role and the start of
    /// the next one, with overlapping roles merged. Roles without a start date are skipped.
    static func largestGapMonths(_ experiences: [Experience], now: Date = .now) -> Int {
        let today = Calendar.current.dateComponents([.year, .month], from: now)
        let todayIndex = (today.year ?? 0) * 12 + (today.month ?? 1)
        let index = { (value: YearMonth) in value.year * 12 + (value.month ?? 1) }
        let spans = experiences
            .filter { $0.kind == .professional }
            .compactMap { record -> (start: Int, end: Int)? in
                guard let start = record.start else { return nil }
                let end = record.isCurrent ? todayIndex : record.end.map(index) ?? index(start)
                return (index(start), max(index(start), end))
            }
            .sorted { $0.start < $1.start }
        var largest = 0
        var reach: Int?
        for span in spans {
            if let reach { largest = max(largest, span.start - reach) }
            reach = max(reach ?? span.end, span.end)
        }
        return largest
    }

    /// Summed spans of professional experience, start to end or to today when current (spec §4.3).
    static func yearsOfExperience(_ experiences: [Experience], now: Date = .now) -> Double {
        let today = Calendar.current.dateComponents([.year, .month], from: now)
        let months = { (value: YearMonth) in value.year * 12 + (value.month ?? 1) }
        let total = experiences
            .filter { $0.kind == .professional }
            .compactMap { record -> Int? in
                guard let start = record.start else { return nil }
                let end = record.isCurrent || record.end == nil
                    ? (today.year ?? 0) * 12 + (today.month ?? 1)
                    : months(record.end!)
                return max(0, end - months(start))
            }
            .reduce(0, +)
        return Double(total) / 12
    }

    private static func fetch<M: PersistentModel>(_ type: M.Type, _ predicate: Predicate<M>?, in context: ModelContext) -> [M] {
        (try? context.fetch(FetchDescriptor<M>(predicate: predicate))) ?? []
    }
}

/// An invisible view that feeds the engine: a visit when the screen or record changes, a
/// debounced check on every edit, and the blockers (spec §5.1).
struct OviWatcher: View {
    let isSidebarCollapsed: Bool

    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(OviEngine.self) private var ovi
    @Environment(UnsavedChangesGuard.self) private var changes
    /// Read so a new skill (an insert, which fetching doesn't observe) updates the signature.
    @Query private var skills: [Skill]

    private struct Visit: Equatable {
        let section: AppSection
        let category: ProfileCategory
        let record: UUID?
        let isOnSkills: Bool
    }

    var body: some View {
        // Reading the records here makes this view update whenever they change (Observation).
        let isNew = changes.active?.isNew ?? false
        let built = OviContextBuilder.make(navigation: navigation, in: context, isNewRecord: isNew, full: false)
        let skillCount = skills.count
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(
                of: Visit(section: navigation.section, category: navigation.profileCategory, record: navigation.openRecordID, isOnSkills: navigation.isOnSkills),
                initial: true
            ) {
                // A first save only counts for the record it was made on.
                if navigation.justSavedRecordID != navigation.openRecordID { navigation.justSavedRecordID = nil }
                if navigation.justExportedResumeID != navigation.openRecordID { navigation.justExportedResumeID = nil }
                ovi.visit(built?.context)
            }
            .onChange(of: built?.signature) {
                ovi.dataChanged(built?.context)
            }
            .onChange(of: skillCount) {
                ovi.dataChanged(built?.context)
            }
            // A sheet blocked the "!" while it was open; look again once it's gone.
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndSheetNotification)) { _ in
                // The window may still list the sheet as it posts this; look a moment later.
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    ovi.recheck()
                }
            }
            .onChange(of: navigation.revertCount) {
                ovi.discarded()
            }
            .onChange(of: isSidebarCollapsed, initial: true) { _, collapsed in
                ovi.setBlocked(collapsed)
            }
            .onAppear {
                ovi.contextProvider = { [navigation, context, changes] in
                    OviContextBuilder.make(navigation: navigation, in: context, isNewRecord: changes.active?.isNew ?? false)?.context
                }
                ovi.externalBlocker = {
                    NSApp.windows.contains { $0.attachedSheet != nil }
                        || ((NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false)
                }
            }
    }
}
