//
//  CopyPrompt.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation

/// A ready-made prompt for any AI (ChatGPT, Gemini, Claude on the web), filled with what's on
/// screen, for people without Claude Desktop. It never includes contact details, and it says what
/// it includes before it's copied (DESIGN.md: Copy Prompt).
nonisolated struct CopyPrompt: Equatable {
    let title: String
    let text: String
    /// Shown before copying: what goes to the clipboard.
    let includes: [String]
    let excludes: [String]

    /// The rules every prompt ends with: truthful, plain, choices to pick from.
    private static let rules = """
        Rules:
        - Never invent facts, tools, or numbers. Where a number would help and I haven't given one, write [number] so I can fill it in.
        - Start bullets with a strong action verb and show the result (what changed, by how much).
        - Plain text only: no tables, emoji, or special characters, so it stays readable by applicant tracking systems.
        - Give me 2–3 labeled versions (Version A, B, C) so I can pick.
        - Reply in the same language as my content.
        """

    // MARK: Improve bullets (Experience, Project)

    static func improveBullets(role: String, organization: String, bullets: [String]) -> CopyPrompt {
        let bullets = clean(bullets)
        let what = bullets.isEmpty
            ? "I have no bullets yet. Ask me up to three short questions about what I did and what changed, then draft 3 bullets."
            : "Here are my bullets:\n" + bullets.map { "- \($0)" }.joined(separator: "\n")
        let text = """
            You're an experienced career coach helping me improve the bullets for one entry on my resume.

            Role: \(role)
            Organization: \(organization)

            \(what)

            Rewrite them so each shows what I did and the result. Keep each bullet to one line or two.

            \(rules)
            """
        var includes = [String(localized: "Role and organization")]
        if !bullets.isEmpty { includes.append(bullets.count == 1 ? String(localized: "1 bullet") : String(localized: "\(bullets.count) bullets")) }
        return CopyPrompt(
            title: String(localized: "Improve These Bullets"),
            text: text,
            includes: includes,
            excludes: [String(localized: "Your name and contact details"), String(localized: "Other records")]
        )
    }

    // MARK: Write a summary (resume)

    static func writeSummary(_ resume: ResumeDocument) -> CopyPrompt {
        let current = resume.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = """
            You're an experienced career coach. Write the summary at the top of my resume: 2–3 sentences that say what I do, my strongest skills, and the result I'm known for. No first person ("I"), no clichés like "hard worker" or "team player".

            Headline: \(resume.header.headline.isEmpty ? "(none)" : resume.header.headline)
            \(current.isEmpty ? "I have no summary yet." : "My summary now: \(current)")

            My resume:
            \(body(of: resume))

            \(rules)
            """
        return CopyPrompt(
            title: String(localized: "Write a Summary"),
            text: text,
            includes: [String(localized: "Headline and summary"), String(localized: "This resume's sections, entries, and bullets")],
            excludes: [String(localized: "Your name, email, phone, location, and links")]
        )
    }

    // MARK: Tailor to a job (application)

    static func tailor(position: String, company: String, jobDescription: String, resume: ResumeDocument?) -> CopyPrompt {
        let mine = resume.map { "My resume:\n" + body(of: $0) }
            ?? "I have no resume for this job yet. Ask me for my experience first."
        let text = """
            You're an experienced recruiter helping me tailor my resume to one job. Never invent experience I don't have.

            Job: \(position) at \(company)
            Job description:
            \(jobDescription.trimmingCharacters(in: .whitespacesAndNewlines))

            \(mine)

            Tell me: which of my bullets matter most for this job, how to reword them with the job's own terms where they truthfully apply, and what the job asks for that my resume doesn't show yet.

            \(rules)
            """
        var includes = [String(localized: "Position and company"), String(localized: "Job description")]
        if resume != nil { includes.append(String(localized: "The resume's sections, entries, and bullets")) }
        return CopyPrompt(
            title: String(localized: "Tailor to This Job"),
            text: text,
            includes: includes,
            excludes: [String(localized: "Your name, email, phone, location, and links")]
        )
    }

    // MARK: Helpers

    /// A resume as plain text, without the header (name and contact details stay out).
    private static func body(of resume: ResumeDocument) -> String {
        resume.sections.map { section in
            let entries = section.entries.map { entry in
                let line = [entry.title, entry.subtitle].filter { !$0.isEmpty }.joined(separator: " — ")
                let bullets = clean(entry.bullets).map { "  - \($0)" }
                return ([line.isEmpty ? "(untitled)" : line] + bullets).joined(separator: "\n")
            }
            return ([section.title.uppercased()] + entries).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private static func clean(_ lines: [String]) -> [String] {
        lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
