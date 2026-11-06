//
//  PreviewData.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

#if DEBUG
import SwiftData
import SwiftUI

extension ModelContainer {
    /// In-memory store with sample records, for SwiftUI previews and `-CivaSampleData YES`.
    /// Real brand names so the logo lookup has something to find; debug builds only.
    static let preview: ModelContainer = {
        let container = try! ModelContainer.civa(inMemory: true)
        let context = container.mainContext

        let swift = Skill(name: "Swift", category: "Languages")
        let kotlin = Skill(name: "Kotlin", category: "Languages")
        let swiftUI = Skill(name: "SwiftUI", category: "Frameworks")
        let swiftData = Skill(name: "SwiftData", category: "Frameworks")
        let figma = Skill(name: "Figma", category: "Tools", status: .needsReview)

        let current = Experience(
            kind: .professional,
            organization: "Tokopedia",
            role: "iOS Engineer",
            location: "Jakarta",
            start: YearMonth(year: 2024, month: 3),
            isCurrent: true,
            details: "Built the onboarding flow and the offline sync layer.",
            impacts: ["Cut onboarding drop-off by 18%", "Shipped offline cart sync used by 2M weekly buyers"],
            customFields: [CustomField(name: "Team Size", value: "6")]
        )
        current.skills = [swift, swiftUI, swiftData]
        let internship = Experience(
            kind: .professional,
            organization: "Traveloka",
            role: "Mobile Intern",
            location: "Jakarta",
            start: YearMonth(year: 2023, month: 6),
            end: YearMonth(year: 2023, month: 12),
            impacts: ["Rebuilt the booking summary screen in SwiftUI"],
            status: .needsReview
        )
        internship.skills = [swift, kotlin]
        let academy = Experience(
            kind: .organizational,
            organization: "Apple Developer Academy",
            role: "Learner",
            location: "Jakarta",
            start: YearMonth(year: 2025, month: 3),
            isCurrent: true
        )
        let degree = Education(
            institution: "Universitas Indonesia",
            degree: "Bachelor of Computer Science",
            location: "Depok",
            start: YearMonth(year: 2019),
            end: YearMonth(year: 2023),
            grade: "3.7 / 4.0"
        )
        let project = Project(
            name: "Civa",
            role: "Solo Developer",
            start: YearMonth(year: 2026, month: 11),
            details: "A local-first career workspace for macOS."
        )
        project.skills = [swift, swiftUI, swiftData, figma]
        let award = Achievement(title: "Best Pitching Team", issuer: "Apple Developer Academy", date: YearMonth(year: 2025, month: 8))
        award.experience = academy

        let day = 86_400.0
        let applications = [
            JobApplication(company: "Apple", position: "iOS Engineer", applicationDate: .now - day * 40, status: .offer),
            JobApplication(company: "Google", position: "Software Engineer, iOS", applicationDate: .now - day * 21, status: .interview),
            JobApplication(company: "Microsoft", position: "Mobile Engineer", applicationDate: .now - day * 18, status: .interview),
            JobApplication(company: "Grab", position: "Senior iOS Engineer", applicationDate: .now - day * 14, status: .assessment),
            JobApplication(company: "Spotify", position: "iOS Engineer, Playback", applicationDate: .now - day * 6, status: .applied),
            JobApplication(company: "Stripe", position: "Mobile Engineer, SDK", applicationDate: .now - day * 3, status: .applied),
            JobApplication(company: "Shopee", position: "iOS Developer", applicationDate: .now - day * 60, status: .rejected),
            JobApplication(company: "Airbnb", position: "iOS Engineer", applicationDate: .now - day * 50, status: .withdrawn),
            JobApplication(company: "Gojek", position: "iOS Engineer, Payments"),
            JobApplication(company: "Netflix", position: "Senior iOS Engineer"),
        ]
        let organizations = [
            ("Tokopedia", "tokopedia.com"), ("Traveloka", "traveloka.com"), ("Apple Developer Academy", "apple.com"),
            ("Universitas Indonesia", "ui.ac.id"), ("Apple", "apple.com"), ("Google", "google.com"),
            ("Microsoft", "microsoft.com"), ("Grab", "grab.com"), ("Spotify", "spotify.com"), ("Stripe", "stripe.com"),
            ("Shopee", "shopee.com"), ("Airbnb", "airbnb.com"), ("Gojek", "gojek.com"), ("Netflix", "netflix.com"),
        ].map { Organization(name: $0.0, domain: $0.1) }

        // An earlier CV import that matched the current job but was added separately (FR-024).
        let cvSource = RecordSource(name: "alex-cv-2025.pdf", date: .now - 86_400 * 30)
        current.sources = [.manual(), cvSource]
        let duplicate = Experience(
            kind: .professional,
            organization: "PT Tokopedia",
            role: "Senior iOS Engineer",
            location: "Jakarta",
            start: YearMonth(year: 2024, month: 6),
            isCurrent: true,
            impacts: ["Cut onboarding drop-off by 18%", "Mentored two junior engineers"],
            status: .needsReview
        )
        duplicate.sources = [cvSource]
        duplicate.possibleDuplicateOf = current.id

        let records: [any PersistentModel] = [
            PersonalInfo(fullName: "Alex Morgan", headline: "iOS Engineer", email: "alex@example.com", location: "Jakarta"),
            duplicate, current, internship, academy, degree, project, award,
            Certification(name: "App Development with Swift", issuer: "Apple", issued: YearMonth(year: 2024, month: 5)),
        ] + applications + organizations
        records.forEach { context.insert($0) }
        let resumes = sampleResumes()
        resumes.forEach { context.insert($0) }
        addSampleHistory(to: resumes[0], in: context)
        applications[0].resume = resumes[1]  // Apple gets the tailored resume
        applications[1...5].forEach { $0.resume = resumes[0] }
        try! context.save()
        return container
    }()

    /// A few versions so History has something to compare.
    private static func addSampleHistory(to resume: Resume, in context: ModelContext) {
        let current = resume.document
        var first = current
        first.summary = "iOS engineer who builds native apps."
        first.sections[0].entries.removeLast()
        first.format.font = .georgia
        var second = current
        second.sections[0].entries[0].bullets.removeLast()
        let versions: [(SnapshotReason, String, ResumeDocument, Double)] = [
            (.created, "", first, 3),
            (.checkpoint, "Before adding the internship", second, 1),
            (.exported, "", current, 0.1),
        ]
        for (reason, name, document, daysAgo) in versions {
            let snapshot = ResumeSnapshot(reason: reason, name: name, document: document, createdAt: .now - 86_400 * daysAgo)
            context.insert(snapshot)
            snapshot.resume = resume
        }
    }

    private static func sampleResumes() -> [Resume] {
        var base = ResumeDocument.blank
        base.header = ResumeHeader(
            fullName: "Alex Morgan", headline: "iOS Engineer", email: "alex@example.com", phone: "+62 812 0000 0000",
            location: "Jakarta", links: [ProfileLink(label: "GitHub", url: "github.com/alexmorgan")]
        )
        base.summary = "iOS engineer building native, offline-first apps in Swift and SwiftUI."
        base.sections[0].entries = [
            ResumeEntry(title: "iOS Engineer", subtitle: "Tokopedia · Jakarta", dates: "Mar 2024 – Present",
                        bullets: ["Cut onboarding drop-off by 18%", "Shipped offline cart sync used by 2M weekly buyers"]),
            ResumeEntry(title: "Mobile Intern", subtitle: "Traveloka · Jakarta", dates: "Jun 2023 – Dec 2023",
                        bullets: ["Rebuilt the booking summary screen in SwiftUI"]),
        ]
        base.sections[1].entries = [
            ResumeEntry(title: "Bachelor of Computer Science", subtitle: "Universitas Indonesia · Depok", dates: "2019 – 2023",
                        bullets: ["Grade: 3.7 / 4.0"]),
        ]
        base.sections[2].entries = [
            ResumeEntry(title: "Civa", subtitle: "Solo Developer", dates: "Nov 2026 – Present",
                        bullets: ["A local-first career workspace for macOS"]),
        ]
        base.sections[3].entries = [
            ResumeEntry(title: "Languages", subtitle: "Swift, Kotlin"),
            ResumeEntry(title: "Frameworks", subtitle: "SwiftUI, SwiftData"),
        ]

        var tailored = base
        tailored.format = ResumeFormat(font: .georgia, accent: .navy)
        tailored.summary = "iOS engineer focused on polished, accessible apps built with SwiftUI."

        var product = base
        product.sections.removeAll { $0.kind == .projects }
        product.format = ResumeFormat(font: .arial, fontSize: 10.5, accent: .teal, paper: .letter)

        return [
            {
                let master = Resume(title: "Master Resume", targetPosition: "iOS Developer", document: base)
                master.isMaster = true
                return master
            }(),
            Resume(title: "Apple Application", targetPosition: "iOS Engineer", document: tailored),
            Resume(title: "Product Engineer Resume", targetPosition: "Product Engineer", document: product),
        ]
    }
}

/// Sample files for manual checks.
enum PreviewSamples {
    static let cvText = """
    Rina Wijaya
    Product Designer
    Bandung | rina@example.com | +62 811 2222 3333 | linkedin.com/in/rinawijaya

    PROFILE
    Product designer focused on fintech apps.

    PENGALAMAN KERJA
    Senior Product Designer — Tokopedia
    Jan 2023 – Present
    • Led the checkout redesign, lifting conversion by 9%
    • Built the design system used by 40 designers
    Product Designer at Gojek
    Agustus 2020 - Desember 2022
    - Designed GoPay onboarding

    PENDIDIKAN
    Institut Teknologi Bandung
    S1 Desain Komunikasi Visual, 2016 – 2020

    Certifications
    Google UX Design Certificate (2021)

    Skills
    Design: Figma, Sketch, Prototyping
    Research, Usability Testing

    Hobbies
    Hiking
    """

    /// A Word copy of `cvText` in the app's temporary folder, which the sandbox can read.
    static func writeSampleCV() -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: "Sample CV.docx")
        let text = NSAttributedString(string: cvText)
        guard let data = try? text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        ), (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}

extension RecordEditor {
    /// Editor on a sample record of this type.
    static func preview(needsReview: Bool = false) -> RecordEditor<Model> {
        let context = ModelContainer.preview.mainContext
        let records = try! context.fetch(FetchDescriptor<Model>())
        let record = records.first { $0.needsReview == needsReview } ?? records[0]
        return RecordEditor(record: record, context: context)
    }
}

extension View {
    /// The environment every Civa view expects, backed by sample data.
    func previewEnvironment() -> some View {
        modelContainer(.preview)
            .environment(UnsavedChangesGuard())
            .environment(AppNavigation())
    }
}
#endif
