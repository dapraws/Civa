//
//  OviRules.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation

/// What the rules read: a snapshot of the screen, so the rules stay pure and testable.
struct OviContext {
    var screen: OviScreen
    var experience: Experience?
    var project: Project?
    var skills: [Skill] = []
    var resume: ResumeDocument?
    var resumePageCount = 0
    var application: JobApplication?
    /// Degree level of each Education record, by id, for `highSchool`.
    var educationLevels: [UUID: DegreeLevel] = [:]
    /// Summed spans of professional experience, for `pageCount`'s variant.
    var yearsOfExperience: Double = 0
    /// A new current Experience was just saved for the first time (`numberLog`).
    var justSavedNewCurrentExperience = false
    /// The open record hasn't been saved yet: skipped until its first save (spec §5.1).
    var isNewRecord = false
    /// The longest gap, in months, between professional roles in the profile (`careerGap`).
    var largestGapMonths = 0
    /// This resume was just exported (`proofread`).
    var justExported = false
    /// Applications created in the last 7 days that use this application's resume (`sameResume`).
    var applicationsWithSameResumeThisWeek = 0
}

/// The tip rules of spec §4.2 and their copy (§4.3).
enum OviRules {
    static let weakOpenings = ["responsible for", "helped", "worked on", "assisted", "bertanggung jawab", "membantu"]
    /// Self-praise that's easy to claim and hard to believe (Harvard OCS), English and Indonesian.
    static let selfPraise = [
        "team player", "hard worker", "hard-working", "hardworking", "results-oriented", "results-driven",
        "detail-oriented", "self-motivated", "go-getter", "fast learner", "quick learner", "think outside the box",
        "excellent communication", "pekerja keras", "cepat belajar", "berorientasi pada hasil",
        "mampu bekerja dalam tim", "mampu bekerja sama", "mampu bekerja di bawah tekanan",
    ]

    /// Every tip that matches the screen, in priority order.
    static func matches(in context: OviContext) -> [OviMatch] {
        guard !context.isNewRecord else { return [] }
        return OviTipID.allCases
            .filter { $0.screens.contains(context.screen.kind) }
            .compactMap { match($0, in: context) }
    }

    // MARK: Rules

    private static func match(_ tip: OviTipID, in context: OviContext) -> OviMatch? {
        switch tip {
        case .fontSize:
            guard let size = context.resume?.format.fontSize, size < 10 else { return nil }
            return fontSize(size)
        case .entryDetails:
            guard let record = context.experience else { return nil }
            if record.location.isBlank { return entryDetails(missingLocation: true) }
            if let start = record.start, start.month == nil { return entryDetails(missingLocation: false) }
            return nil
        case .tailor:
            guard let resume = context.application?.resume, resume.isMaster else { return nil }
            return copy(.tailor, action: .tailorCopy(resumeID: resume.id))
        case .numericDates:
            guard context.resume?.format.dateStyle == .numeric else { return nil }
            return copy(.numericDates, action: .useShortDates)
        case .highSchool:
            let levels = (context.resume?.sections ?? [])
                .filter { $0.kind == .education }
                .flatMap(\.entries)
                .compactMap { $0.sourceID.flatMap { context.educationLevels[$0] } }
            let higher: Set<DegreeLevel> = [.diploma, .appliedBachelor, .bachelor, .master, .doctorate]
            guard levels.contains(.highSchool), levels.contains(where: higher.contains) else { return nil }
            return copy(.highSchool)
        case .pageCount:
            guard context.resume != nil, context.resumePageCount >= 2 else { return nil }
            return pageCount(experienced: context.yearsOfExperience >= 3)
        case .actionVerb:
            for bullet in bulletGroups(context).joined() {
                let trimmed = bullet.trimmingCharacters(in: .whitespacesAndNewlines)
                if let opening = weakOpenings.first(where: { trimmed.lowercased().hasPrefix($0) }) {
                    return actionVerb(phrase: String(trimmed.prefix(opening.count)))
                }
            }
            return nil
        case .bulletCount:
            guard let count = bulletGroups(context).map(\.count).first(where: { $0 >= 6 }) else { return nil }
            return bulletCount(count)
        case .addNumber:
            let flat = bulletGroups(context).first { group in
                group.count >= 2 && !group.contains { $0.contains(where: \.isNumber) }
            }
            return flat == nil ? nil : copy(.addNumber)
        case .softSkills:
            let categories = context.screen.kind == .skills
                ? context.skills.map(\.category)
                : (context.resume?.sections ?? []).filter { $0.kind == .skills }.flatMap(\.entries).map(\.title)
            guard categories.contains(where: { $0.localizedCaseInsensitiveContains("soft skill") }) else { return nil }
            return copy(.softSkills)
        case .contactDetails:
            guard let header = context.resume?.header.printed else { return nil }
            let noEmail = header.email.isBlank, noPhone = header.phone.isBlank
            guard noEmail || noPhone else { return nil }
            return contactDetails(noEmail: noEmail, noPhone: noPhone)
        case .sameResume:
            guard let resume = context.application?.resume, !resume.isMaster,
                  context.applicationsWithSameResumeThisWeek >= 5
            else { return nil }
            return sameResume(context.applicationsWithSameResumeThisWeek, resumeID: resume.id)
        case .educationFirst:
            let first = (context.resume?.sections ?? []).first?.kind
            guard first == .education, context.yearsOfExperience >= 3 else { return nil }
            return copy(.educationFirst)
        case .selfPraise:
            let texts = context.screen.kind == .skills
                ? context.skills.map(\.name)
                : [context.resume?.printedSummary ?? ""]
                    + (context.resume?.sections ?? []).filter { $0.kind == .skills }.flatMap(\.entries).flatMap { [$0.title, $0.subtitle] }
            for text in texts {
                if let range = selfPraise.lazy.compactMap({ text.range(of: $0, options: .caseInsensitive) }).first {
                    return selfPraise(phrase: String(text[range]))
                }
            }
            return nil
        case .careerGap:
            guard context.largestGapMonths >= 6 else { return nil }
            return careerGap(context.largestGapMonths)
        case .proofread:
            guard context.justExported else { return nil }
            return copy(.proofread)
        case .numberLog:
            guard context.justSavedNewCurrentExperience, context.experience?.isCurrent == true else { return nil }
            return copy(.numberLog)
        }
    }

    /// Non-blank bullets per record or resume entry: the open record on a record screen, every
    /// experience, organizational and project entry on the resume screen.
    private static func bulletGroups(_ context: OviContext) -> [[String]] {
        let clean = { (lines: [String]) in lines.filter { !$0.isBlank } }
        switch context.screen.kind {
        case .experienceRecord: return context.experience.map { [clean($0.impacts)] } ?? []
        case .projectRecord: return context.project.map { [clean($0.impacts)] } ?? []
        case .resumeEditor:
            return (context.resume?.sections ?? [])
                .filter { [.experience, .organizational, .projects].contains($0.kind) }
                .flatMap(\.entries)
                .map { clean($0.bullets) }
        default: return []
        }
    }

    // MARK: Copy (spec §4.3)

    private static func fontSize(_ size: Double) -> OviMatch {
        let text = size == size.rounded() ? String(Int(size)) : String(size)
        return OviMatch(
            tip: .fontSize,
            title: String(localized: "\(text) pt may be hard to read"),
            body: String(localized: "MIT says never go below 10 pt; 11 pt suits most fonts. It's your call: Civa still exports at \(text)."),
            source: "MIT CAPD",
            action: .setFontSize10
        )
    }

    private static func entryDetails(missingLocation: Bool) -> OviMatch {
        OviMatch(
            tip: .entryDetails,
            title: String(localized: "Add where and when"),
            body: missingLocation
                ? String(localized: "This entry is missing its location. Recruiters expect role, organization, location, and month and year.")
                : String(localized: "This entry has a year but no month. Recruiters expect role, organization, location, and month and year."),
            source: "MIT CAPD"
        )
    }

    private static func pageCount(experienced: Bool) -> OviMatch {
        OviMatch(
            tip: .pageCount,
            title: experienced ? String(localized: "Two pages is fine") : String(localized: "Two pages now"),
            body: experienced
                ? String(localized: "With your experience, two pages is normal. Keep the most relevant work on page one.")
                : String(localized: "For students and new grads, most employers expect one page. Trim what doesn't show impact for this job."),
            source: "NACE"
        )
    }

    private static func actionVerb(phrase: String) -> OviMatch {
        let phrase = phrase.prefix(1).uppercased() + phrase.dropFirst()
        return OviMatch(
            tip: .actionVerb,
            title: String(localized: "Lead with what you did"),
            body: String(localized: "\"\(phrase)\" lists a duty. Try an action verb plus the result, like \"Built…\" or \"Led…\"."),
            source: "MIT CAPD · Harvard"
        )
    }

    private static func bulletCount(_ count: Int) -> OviMatch {
        OviMatch(
            tip: .bulletCount,
            title: String(localized: "Fewer, stronger bullets"),
            body: String(localized: "This entry has \(count) bullets. One strong result beats five routine tasks, so keep the ones that show impact."),
            source: "MIT CAPD"
        )
    }

    private static func contactDetails(noEmail: Bool, noPhone: Bool) -> OviMatch {
        OviMatch(
            tip: .contactDetails,
            title: String(localized: "Add a way to reach you"),
            body: noEmail && noPhone
                ? String(localized: "This resume shows no email or phone. A missing contact detail is one of the most common mistakes.")
                : noEmail
                ? String(localized: "This resume shows no email. Recruiters expect both an email and a phone number.")
                : String(localized: "This resume shows no phone number. Recruiters expect both an email and a phone number."),
            source: "Harvard · MIT CAPD"
        )
    }

    private static func sameResume(_ count: Int, resumeID: UUID) -> OviMatch {
        OviMatch(
            tip: .sameResume,
            title: String(localized: "One resume, \(count) jobs"),
            body: String(localized: "\(count) applications this week use this resume. A copy tailored to each job's wording usually lands better."),
            source: "MIT CAPD · Harvard",
            action: .tailorCopy(resumeID: resumeID)
        )
    }

    private static func selfPraise(phrase: String) -> OviMatch {
        let phrase = phrase.prefix(1).uppercased() + phrase.dropFirst()
        return OviMatch(
            tip: .selfPraise,
            title: String(localized: "Show it instead of saying it"),
            body: String(localized: "\"\(phrase)\" is easy to claim and hard to believe. A bullet about a time you did it says more."),
            source: "Harvard"
        )
    }

    private static func careerGap(_ months: Int) -> OviMatch {
        OviMatch(
            tip: .careerGap,
            title: String(localized: "About the gap"),
            body: String(localized: "There's a \(months)-month gap between roles. A short line, like a course or freelance work, can explain it."),
            source: "Harvard"
        )
    }

    private static func copy(_ tip: OviTipID, action: OviAction? = nil) -> OviMatch {
        let (title, body, source): (String, String, String) = switch tip {
        case .tailor: (
            String(localized: "Tailor this one?"),
            String(localized: "This application uses your Master resume. A copy tailored to the job's wording usually lands better."),
            "Harvard · MIT CAPD")
        case .numericDates: (
            String(localized: "Spell out the months"),
            String(localized: "\"03/04/2024\" reads as March in the US and April in Indonesia. Spelled-out months read the same everywhere."),
            String(localized: "Regional guides"))
        case .highSchool: (
            String(localized: "Time to drop high school?"),
            String(localized: "Once you're at university, your high school entry can usually go. Keep it only for strong scores or coursework."),
            "MIT CAPD")
        case .addNumber: (
            String(localized: "Any number you could add?"),
            String(localized: "Results with a number stand out, like \"cut wait time by 20%\". An honest estimate is fine to start."),
            "MIT CAPD")
        case .softSkills: (
            String(localized: "About soft skills"),
            String(localized: "MIT suggests showing skills like leadership in your bullets instead of the Skills list. Keep them if you like."),
            "MIT CAPD")
        case .educationFirst: (
            String(localized: "Experience first now?"),
            String(localized: "With a few years of work, most resumes put Experience above Education. Drag it down in the outline."),
            "MIT CAPD")
        case .proofread: (
            String(localized: "Read it once more"),
            String(localized: "Typos are one of the most common reasons a resume gets passed over. Reading it aloud catches what spellcheck misses."),
            "Harvard")
        case .numberLog: (
            String(localized: "Start a number log"),
            String(localized: "For this current role, note one number a month: users, hours saved, sales. Later bullets will need them."),
            "MIT CAPD")
        default: ("", "", "")
        }
        return OviMatch(tip: tip, title: title, body: body, source: source, action: action)
    }

    /// The longest form of every tip, for the bubble-length check.
    static var longestVariants: [OviMatch] {
        [
            fontSize(9.5),
            entryDetails(missingLocation: true), entryDetails(missingLocation: false),
            copy(.tailor), copy(.numericDates), copy(.highSchool),
            pageCount(experienced: true), pageCount(experienced: false),
            actionVerb(phrase: "Bertanggung jawab"),
            bulletCount(99),
            copy(.addNumber), copy(.softSkills), copy(.numberLog),
            contactDetails(noEmail: true, noPhone: true), contactDetails(noEmail: true, noPhone: false), contactDetails(noEmail: false, noPhone: true),
            sameResume(99, resumeID: UUID()),
            copy(.educationFirst),
            selfPraise(phrase: "mampu bekerja di bawah tekanan"),
            careerGap(120),
            copy(.proofread),
        ]
    }
}
