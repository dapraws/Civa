//
//  HelpView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Civa Help: short pages on each part of the app, opened from Help → Civa Help (⌘?).
struct HelpView: View {
    @State private var selection: HelpTopic.ID? = HelpTopic.all.first?.id
    @State private var query = ""
    @AppStorage(CivaTips.resetKey) private var resetsTips = false

    var body: some View {
        NavigationSplitView {
            List(topics, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.symbol)
                    .foregroundStyle(topic.id == "claude" ? Color.claude : .primary)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Show All Tips Again") { resetsTips = true }
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
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(topic.id == "claude" ? Color.claude : .primary)
                if topic.id == "claude" {
                    ClaudeHowItWorks()
                        .padding(14)
                        .background(Color.claude.opacity(0.08), in: .rect(cornerRadius: 10))
                }
                ForEach(topic.sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading).font(.title3.weight(.semibold))
                        Text(section.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(topic.title)
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
            (String(localized: "Documents"), String(localized: "Keep certificates, transcripts, and other files here, and link them to the records they support. Linking doesn't change the record.")),
        ]),
        HelpTopic("claude", String(localized: "Working with Claude"), "sparkles", [
            (String(localized: "Optional"), String(localized: "Civa works fully on its own. If you use Claude Desktop, you can connect it in Settings to write summaries, improve bullets, or draft tailored resumes.")),
            (String(localized: "What Claude Can See"), String(localized: "In Settings you choose, per category, whether Claude can read and whether it can suggest changes. Records that still need review are never shared.")),
            (String(localized: "Nothing Changes Without You"), String(localized: "Claude's suggestions wait in AI Activity and on the resume they're for. You pick a version, apply it, or discard it. AI Activity also lists everything Claude read.")),
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
