//
//  HelpView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// A topic another window asked Help to show, such as Ovi's Why?.
@Observable
final class HelpNavigator {
    static let shared = HelpNavigator()
    var topic: String?
}

/// Civa Help: short pages on each part of the app, opened from Help → Civa Help (⌘?).
struct HelpView: View {
    @State private var selection: HelpTopic.ID? = HelpTopic.all.first?.id
    @State private var query = ""
    @AppStorage(CivaTips.resetKey) private var resetsTips = false

    var body: some View {
        NavigationSplitView {
            List(topics, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.symbol)
                    .foregroundStyle(topic.id == "claude" ? Color.claudeText : Color.textPrimary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Show All Tips Again") { resetsTips = true }
                        .civaButton(.secondary)
                        .disabled(resetsTips)
                    if resetsTips {
                        Text("Tips show again the next time you open Civa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        } detail: {
            if let topic = HelpTopic.all.first(where: { $0.id == selection }) {
                HelpPage(topic: topic)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search Help")
        .onChange(of: HelpNavigator.shared.topic, initial: true) { _, topic in
            guard let topic else { return }
            query = ""
            selection = topic
            HelpNavigator.shared.topic = nil
        }
        .onChange(of: query) {
            if let first = topics.first, !topics.contains(where: { $0.id == selection }) { selection = first.id }
        }
    }

    private var topics: [HelpTopic] {
        HelpTopic.all.filter { $0.matches(query) }
    }
}

private struct HelpPage: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(topic.title, systemImage: topic.symbol)
                    .font(.pageTitle)
                    .foregroundStyle(topic.id == "claude" ? Color.claudeText : Color.textPrimary)
                if topic.id == "claude" {
                    ClaudeHowItWorks()
                        .padding(14)
                        .background(Color.claudeTint, in: .rect(cornerRadius: Radius.card))
                }
                ForEach(topic.sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading).font(.sectionTitle)
                        Text(section.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: Size.readingWidth, alignment: .leading)
            .padding(Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.canvas)
    }
}

/// One Help page.
struct HelpTopic: Identifiable {
    struct Section {
        let heading: String
        let text: String
    }

    let id: String
    let title: String
    let symbol: String
    let sections: [Section]

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query)
            || sections.contains { $0.heading.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }
    }

    private init(_ id: String, _ title: String, _ symbol: String, _ sections: [(String, String)]) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.sections = sections.map { Section(heading: $0.0, text: $0.1) }
    }

    static let all: [HelpTopic] = [
        HelpTopic("start", String(localized: "Getting Started"), "flag.checkered", [
            (String(localized: "What Civa Is For"), String(localized: "Civa keeps your career details in one place on this Mac: experience, education, projects, skills, and more. From them you make resumes for different jobs, without retyping anything.")),
            (String(localized: "Three Ways to Start"), String(localized: "Import a CV or LinkedIn PDF, import your LinkedIn data export, or add things by hand. You can mix them later. Help → Show Welcome opens the start screen again.")),
            (String(localized: "Getting Started List"), String(localized: "The Dashboard lists what's left before your first resume goes out, and ticks steps off by itself. Show Me takes you to each one. Hide it when you're done; Help → Show Getting Started brings it back.")),
        ]),
        HelpTopic("profile", String(localized: "Career Profile"), "person.text.rectangle", [
            (String(localized: "Your Facts in One Place"), String(localized: "The Career Profile holds everything about you, by category. Resumes copy from it, so you write each fact once.")),
            (String(localized: "Needs Review"), String(localized: "Imported records start as Needs Review. Check them and press Confirm; until then they're never used in a resume or shared with Claude.")),
            (String(localized: "Saving"), String(localized: "Changes stay unsaved until you press Save. If you leave a page with unsaved changes, Civa asks first.")),
        ]),
        HelpTopic("import", String(localized: "Importing"), "square.and.arrow.down", [
            (String(localized: "What You Can Import"), String(localized: "A CV as PDF or Word (.docx), a LinkedIn profile saved as PDF, or LinkedIn's data export (the ZIP from Settings & Privacy → Data Privacy). Use Import on the Dashboard or Career Profile.")),
            (String(localized: "Nothing Saves Until You Say So"), String(localized: "Civa shows what it found first. Fix anything, leave out what you don't want, then save. If something looks like a record you already have, Civa asks whether to merge it or keep both.")),
        ]),
        HelpTopic("skills", String(localized: "Skills"), "star", [
            (String(localized: "Categories You Name"), String(localized: "Give each skill any category you like, such as Hard Skills, Soft Skills, Languages, or Tools. Skills with the same category are listed together, on the Skills page and on your resumes.")),
            (String(localized: "Moving Skills"), String(localized: "Drag a skill chip onto a category in the list to move it there.")),
            (String(localized: "Where You Used It"), String(localized: "Link a skill from an experience or project to show where you used it.")),
        ]),
        HelpTopic("resumes", String(localized: "Resumes"), "doc.text", [
            (String(localized: "Making a Resume"), String(localized: "Use New Resume to start blank or from your Career Profile, picking what goes in. Set one resume as your Master Resume; Tailor from Master Resume starts a copy for a specific job.")),
            (String(localized: "A Resume Is Its Own Copy"), String(localized: "Editing a resume never changes your Career Profile or another resume. When your profile changes later, the resume shows Suggested changes you can apply or skip.")),
            (String(localized: "History"), String(localized: "Every save and export keeps the version before it. History lets you look back and restore one.")),
        ]),
        HelpTopic("format", String(localized: "Formatting and Templates"), "textformat", [
            (String(localized: "The Ribbon"), String(localized: "The ribbon above the preview formats the whole resume: template, font, size, color, spacing, margins, dividers, dates, and paper. Turn on Guides to see each distance on the page; hovering a spacing control shows its own.")),
            (String(localized: "Templates"), String(localized: "Classic is Civa's own. MIT and Harvard follow those universities' career office samples, and Tech follows a layout common in tech hiring. All are single-column text that applicant tracking systems read well.")),
            (String(localized: "Proof Check"), String(localized: "Add a proof link to an entry and its title gets a small check and opens the link from the PDF. Turn Proof Check off in the ribbon to drop the checks from the whole resume.")),
        ]),
        HelpTopic("eye", String(localized: "Showing and Hiding Details"), "eye", [
            (String(localized: "The Eye"), String(localized: "Next to optional details in the resume editor, such as your phone, a link, the summary, dates, a location, or a GPA, the eye shows or hides it on this resume only.")),
            (String(localized: "Why Not Just Delete It"), String(localized: "Hiding keeps what you typed, so you can bring it back for the next job without looking it up again.")),
        ]),
        HelpTopic("export", String(localized: "Exporting"), "square.and.arrow.up", [
            (String(localized: "Export PDF"), String(localized: "Export PDF saves the resume as a text-based PDF that applicant tracking systems can read. Before saving, Civa points out anything that may need attention, like a missing email or an entry without a title.")),
        ]),
        HelpTopic("applications", String(localized: "Applications and Documents"), "tray.full", [
            (String(localized: "Applications"), String(localized: "Track the jobs you're interested in and where each one stands. Paste the job description and link the resume you sent.")),
            (String(localized: "Documents"), String(localized: "Keep certificates, transcripts, and other files here once. Attach Document on any record or application picks from them, so you never look for the file again; From Finder adds a new one. One file can go on many records, and linking never changes the record.")),
        ]),
        HelpTopic("claude", String(localized: "Working with Claude"), "sparkles", [
            (String(localized: "Optional"), String(localized: "Civa works fully on its own. If you use Claude Desktop, you can connect it in Settings to write summaries, improve bullets, or draft tailored resumes.")),
            (String(localized: "What Claude Can See"), String(localized: "In Settings you choose, per category, whether Claude can read and whether it can suggest changes. Records that still need review are never shared.")),
            (String(localized: "Nothing Changes Without You"), String(localized: "Claude's suggestions wait in AI Activity and on the resume they're for. You pick a version, apply it, or discard it. AI Activity also lists everything Claude read.")),
        ]),
        // Draft copy for the user's review before release (tip engine spec §7.3).
        HelpTopic("ovi", String(localized: "Ovi's Tips"), "lightbulb", [
            (String(localized: "How Ovi Works"), String(localized: "Ovi sits at the bottom of the sidebar. When it spots something on the screen you're working on, a ! appears; click Ovi to read the tip, or ignore it. Ovi never interrupts your typing, shows at most one tip per screen and three a day, and works offline. Close a tip to quiet it for 14 days, choose Don't Show This Again to end it, or turn Ovi off in Settings.")),
            (String(localized: "Font Size"), String(localized: "Small text is hard to read on screen and in print, and recruiters skim quickly. MIT's career office says never to go below 10 pt, and 11 pt suits most fonts. Civa still lets you export at any size; it's your call. Ovi brings this up in the resume editor when the font is under 10 pt. Source: MIT CAPD, capd.mit.edu/resources/sample-resumes")),
            (String(localized: "Where and When"), String(localized: "Recruiters expect each entry to show the role, the organization, the location, and month and year for the dates. A missing location or a year without a month makes an entry look unfinished. Ovi brings this up on an experience that's missing its location or its start month. Source: MIT CAPD, capd.mit.edu/resources/sample-resumes")),
            (String(localized: "Tailoring"), String(localized: "A resume tailored to a job's wording usually does better than a general one, because recruiters and tracking systems look for the posting's own terms. Keep your Master resume as the full version and make a copy for each job. Ovi brings this up on an application that still uses the Master resume. Source: Harvard Office of Career Services and MIT CAPD")),
            (String(localized: "Spelled-Out Months"), String(localized: "Numeric dates like 03/04/2024 read as March in the US and April in Indonesia and much of Europe. Spelled-out months, like Mar 2024, read the same everywhere. Ovi brings this up in the resume editor when dates are set to numbers. Source: regional resume guides, such as jobera.com/indonesia-resume-writing-guide")),
            (String(localized: "High School"), String(localized: "Once you're at university, your high school entry usually takes space that newer work could use. Keep it only if it shows something strong, such as top scores or relevant coursework. Ovi brings this up when a resume lists both high school and a university degree. Source: MIT CAPD, capd.mit.edu")),
            (String(localized: "Page Count"), String(localized: "For students and new graduates, most employers expect one page; with several years of experience, two pages is normal. Either way, keep the most relevant work on page one. Ovi brings this up once, when a resume first reaches two pages. Source: NACE, and resumego.net/research/how-long-should-a-resume-be")),
            (String(localized: "Action Verbs"), String(localized: "Lines like “Responsible for” or “Helped with” describe duties, not what you achieved. Starting with an action verb plus the result, like “Built…” or “Led…”, shows impact at a glance. Ovi brings this up when a bullet starts with a duty phrase, in English or Indonesian. Source: MIT CAPD and Harvard")),
            (String(localized: "Fewer, Stronger Bullets"), String(localized: "Long lists of routine tasks bury your best results. Three to five strong bullets per entry usually read better than six or more. Ovi brings this up when an entry has six or more bullets. Source: MIT CAPD")),
            (String(localized: "Numbers"), String(localized: "Results with a number stand out, like “cut wait time by 20%” or “served 4,000 users”. An honest estimate is fine to start. Ovi brings this up when an entry has two or more bullets and none has a number. Source: MIT CAPD")),
            (String(localized: "Soft Skills"), String(localized: "Listing “teamwork” or “leadership” in a skills section is easy to claim and hard to believe. MIT suggests showing them in your bullets instead, through what you did. Keep them in your list if you like. Ovi brings this up once, when it sees a soft-skills category. Source: MIT CAPD")),
            (String(localized: "Number Log"), String(localized: "Numbers are easiest to collect while you're in a role. Note one a month, such as users, hours saved or sales, so your future bullets have them. Ovi brings this up once, after you add a current role. Source: MIT CAPD")),
        ]),
        HelpTopic("privacy", String(localized: "Privacy"), "lock", [
            (String(localized: "Stays on This Mac"), String(localized: "Your data is stored only on this Mac. Civa has no account and no server.")),
            (String(localized: "Logos"), String(localized: "When you type a company or school name, Civa looks up its logo online, sending only that name. Turn this off in Settings. Logos never appear on your resume.")),
        ]),
    ]
}

#Preview {
    HelpView()
        .frame(width: 860, height: 560)
}
