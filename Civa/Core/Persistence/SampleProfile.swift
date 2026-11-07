//
//  SampleProfile.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

#if DEBUG
import AppKit
import SwiftData

/// A fictional person with a strong, realistic CV, so every screen has something to test in debug
/// builds. Real companies and schools let logo lookup work; contact details and proof links are
/// placeholders that point nowhere real.
enum SampleProfile {
    private static let day = 86_400.0

    static func populate(_ context: ModelContext) {
        // MARK: Skills
        func skill(_ name: String, _ category: String, _ status: ReviewStatus = .confirmed) -> Skill {
            let skill = Skill(name: name, category: category, status: status)
            skill.type = category == "Soft Skills" ? .soft : .hard
            return skill
        }
        let swift = skill("Swift", "Languages")
        let kotlin = skill("Kotlin", "Languages")
        let python = skill("Python", "Languages")
        let typeScript = skill("TypeScript", "Languages")
        let swiftUI = skill("SwiftUI", "Frameworks")
        let uiKit = skill("UIKit", "Frameworks")
        let swiftData = skill("SwiftData", "Frameworks")
        let combine = skill("Combine", "Frameworks")
        let coreML = skill("Core ML", "Frameworks")
        let tools = ["Xcode", "Instruments", "Git", "Firebase", "Figma"].map { skill($0, "Tools") }
        let soft = ["Mentoring", "Technical Writing", "Cross-team Collaboration"].map { skill($0, "Soft Skills") }
        let pyTorch = skill("PyTorch", "AI/ML", .needsReview)  // from a CV import, not yet confirmed
        let skills = [swift, kotlin, python, typeScript, swiftUI, uiKit, swiftData, combine, coreML, pyTorch] + tools + soft

        // MARK: Experience
        let cvSource = RecordSource(name: "raka-pratama-cv-2025.pdf", date: .now - day * 30)
        let gojek = Experience(
            kind: .professional, organization: "Gojek", role: "iOS Engineer", location: "Jakarta, Indonesia",
            start: YearMonth(year: 2024, month: 8), isCurrent: true,
            details: "Payments squad, owning the GoPay checkout and payment confirmation flows.",
            impacts: [
                "Rebuilt the GoPay payment confirmation flow in SwiftUI, cutting checkout drop-off by 14%",
                "Cut cold-start time by 38% by deferring SDK setup and trimming launch work found with Instruments",
                "Made the payments flow fully usable with VoiceOver across 22 screens",
            ],
            customFields: [CustomField(name: "Team Size", value: "8")]
        )
        gojek.employmentType = .fullTime
        gojek.workArrangement = .hybrid
        gojek.skills = [swift, swiftUI, combine, tools[1]]
        gojek.sources = [.manual(), cvSource]

        let tokopedia = Experience(
            kind: .professional, organization: "Tokopedia", role: "Software Engineer Intern, iOS", location: "Jakarta, Indonesia",
            start: YearMonth(year: 2024, month: 2), end: YearMonth(year: 2024, month: 7),
            impacts: [
                "Built a reusable product card component adopted by 6 feature teams",
                "Raised UI test coverage from 41% to 68% with snapshot tests",
            ]
        )
        tokopedia.employmentType = .internship
        tokopedia.workArrangement = .onSite
        tokopedia.skills = [swift, uiKit, swiftUI]

        let telkom = Experience(
            kind: .professional, organization: "Telkom Indonesia", role: "Machine Learning Engineer Intern", location: "Bandung, Indonesia",
            start: YearMonth(year: 2023, month: 7), end: YearMonth(year: 2023, month: 12),
            impacts: [
                "Automated invoice reconciliation with Python and Power Automate, saving the finance team 30+ hours a month",
                "Fine-tuned an IndoBERT model to route support tickets, reaching 0.91 F1",
            ]
        )
        telkom.employmentType = .internship
        telkom.workArrangement = .onSite
        telkom.proofURL = "https://credentials.example.com/telkom-internship/RP-2023"
        telkom.skills = [python]

        let research = Experience(
            kind: .professional, organization: "Telkom University", role: "Research Assistant, Mobile", location: "Bandung, Indonesia",
            start: YearMonth(year: 2023, month: 3), end: YearMonth(year: 2023, month: 6),
            impacts: ["Built a Flutter dashboard to visualize vehicle telemetry for a campus research study"],
            status: .needsReview
        )
        research.employmentType = .partTime

        // Imported from an older CV; it matches the Gojek job, so it's flagged for comparison (FR-024).
        let duplicate = Experience(
            kind: .professional, organization: "PT Gojek Indonesia", role: "iOS Engineer II", location: "Jakarta",
            start: YearMonth(year: 2024, month: 8), isCurrent: true,
            impacts: ["Rebuilt the GoPay payment confirmation flow in SwiftUI", "Onboarded and mentored two new joiners"],
            status: .needsReview
        )
        duplicate.sources = [cvSource]
        duplicate.possibleDuplicateOf = gojek.id

        let bangkit = Experience(
            kind: .organizational, organization: "Bangkit Academy led by Google, Tokopedia, Gojek & Traveloka",
            role: "Mobile Development Cohort", location: "Remote",
            start: YearMonth(year: 2023, month: 2), end: YearMonth(year: 2023, month: 7),
            impacts: [
                "Graduated with Distinction, in the top 10% of 4,000+ participants",
                "Led the 6-person capstone team that built Sehatin, an on-device nutrition tracker",
            ]
        )
        bangkit.organizationType = .program
        bangkit.workArrangement = .remote
        bangkit.recognition = "Graduate with Distinction"
        bangkit.proofURL = "https://credentials.example.com/bangkit-2023/RP-M117"
        let gdg = Experience(
            kind: .organizational, organization: "Google Developer Groups on Campus Telkom University",
            role: "Mobile Development Lead", location: "Bandung, Indonesia",
            start: YearMonth(year: 2023, month: 8), end: YearMonth(year: 2024, month: 7),
            impacts: [
                "Ran a 10-week iOS study group for 120 students",
                "Organized 3 workshops with Google Developer Experts",
            ]
        )
        gdg.organizationType = .community
        gdg.workArrangement = .onSite
        let lab = Experience(
            kind: .organizational, organization: "Mobile Innovation Laboratory, Telkom University",
            role: "Laboratory Assistant", location: "Bandung, Indonesia",
            start: YearMonth(year: 2022, month: 8), end: YearMonth(year: 2024, month: 7),
            impacts: [
                "Taught Swift and Kotlin practicums to 200+ students each semester",
                "Wrote the lab's SwiftUI module, used for 4 semesters",
            ]
        )
        lab.organizationType = .assistant
        lab.workArrangement = .onSite

        // MARK: Education
        let university = Education(
            institution: "Telkom University", degree: "Bachelor of Computer Science", fieldOfStudy: "Informatics",
            location: "Bandung, Indonesia", start: YearMonth(year: 2020, month: 8), end: YearMonth(year: 2024, month: 8),
            details: "Exchange semester at Universiti Teknologi Malaysia, 2023."
        )
        university.degreeLevel = .bachelor
        university.gradeValue = 3.86
        university.gradeLabel = .gpa
        university.thesis = "On-device Indonesian speech recognition for low-end smartphones"
        university.coursework = ["Data Structures", "Mobile Programming", "Machine Learning", "Human-Computer Interaction"]
        university.honors = "Cum Laude"
        university.proofURL = "https://credentials.example.com/telkom-university/diploma-RP-2024"
        let school = Education(
            institution: "SMA Negeri 3 Bandung", degree: "Natural Sciences (IPA)", location: "Bandung, Indonesia",
            start: YearMonth(year: 2017, month: 7), end: YearMonth(year: 2020, month: 6)
        )
        school.degreeLevel = .highSchool
        school.gradeValue = 91.4
        school.gradeScale = 100
        school.gradeLabel = .score

        // MARK: Projects, achievements, certifications
        let sehatin = Project(
            name: "Sehatin", role: "Mobile Lead", url: "https://sehatin.example.com",
            start: YearMonth(year: 2023, month: 4), end: YearMonth(year: 2023, month: 7),
            details: "Bangkit capstone: on-device food recognition for nutrition tracking.",
            impacts: [
                "Recognized 120 Indonesian dishes on-device with a Core ML model at 92% top-5 accuracy",
                "Reached 300 beta testers on TestFlight with a 4.8 rating",
            ]
        )
        sehatin.skills = [swift, swiftUI, coreML]
        sehatin.repositoryURL = "https://github.com/raka-pratama-sample/sehatin"
        let kirana = Project(
            name: "Kirana", role: "Solo Developer", url: "https://kirana.example.com",
            start: YearMonth(year: 2025, month: 1), details: "A SwiftUI budgeting app for shared household expenses.",
            impacts: [
                "Built offline-first sync with SwiftData and CloudKit",
                "Published on the App Store, reaching 1,200+ downloads in three months",
            ]
        )
        kirana.skills = [swift, swiftUI, swiftData]
        kirana.repositoryURL = "https://github.com/raka-pratama-sample/kirana"

        let distinction = Achievement(
            title: "Graduate with Distinction", issuer: "Bangkit Academy", date: YearMonth(year: 2023, month: 7),
            details: "Top 10% of 4,000+ participants in the Mobile Development path."
        )
        distinction.experience = bangkit
        distinction.placement = "Top 10%"
        distinction.proofURL = "https://credentials.example.com/bangkit-2023/distinction-RP-M117"
        let capstone = Achievement(title: "Best Capstone Project", issuer: "Bangkit Academy", date: YearMonth(year: 2023, month: 7))
        capstone.project = sehatin
        capstone.placement = "1st Place"
        let gemastik = Achievement(
            title: "Mobile App Development", issuer: "GEMASTIK XVI", date: YearMonth(year: 2023, month: 10),
            details: "National ICT competition for university students."
        )
        gemastik.placement = "Finalist"

        let azure = Certification(
            name: "Microsoft Certified: Azure AI Fundamentals", issuer: "Microsoft", issued: YearMonth(year: 2024, month: 3),
            credentialID: "AI900-RP-2024", credentialURL: "https://credentials.example.com/azure-ai-fundamentals/AI900-RP-2024"
        )
        let appleCert = Certification(
            name: "App Development with Swift Certified User", issuer: "Apple", issued: YearMonth(year: 2023, month: 5),
            credentialURL: "https://credentials.example.com/app-development-with-swift/ADS-0417"
        )
        let toefl = Certification(name: "TOEFL ITP, Score 590", issuer: "ETS", issued: YearMonth(year: 2024, month: 1))

        let person = PersonalInfo(
            fullName: "Raka Aditya Pratama", headline: "iOS Engineer · SwiftUI & On-Device ML",
            email: "raka.pratama@example.com", phone: "+62 812 0000 2847", location: "Jakarta, Indonesia",
            links: [
                ProfileLink(label: "LinkedIn", url: "linkedin.com/in/raka-pratama-sample"),
                ProfileLink(label: "GitHub", url: "github.com/raka-pratama-sample"),
                ProfileLink(label: "Portfolio", url: "raka-pratama.example.com"),
            ]
        )
        person.summary = "iOS engineer with 2+ years building consumer apps at Indonesian scale. Ships SwiftUI features used by millions, cares about performance and accessibility, and brings on-device machine learning into products."

        let profile: [any PersistentModel] = [
            person, gojek, tokopedia, telkom, research, duplicate, bangkit, gdg, lab, university, school,
            sehatin, kirana, distinction, capstone, gemastik, azure, appleCert, toefl,
        ] + skills
        profile.forEach { context.insert($0) }

        // MARK: Applications
        let applications = sampleApplications()
        applications.forEach { context.insert($0) }
        organizations().forEach { context.insert($0) }
        documents(certificate: azure, project: kirana, experience: tokopedia).forEach { context.insert($0) }

        // MARK: Resumes
        var master = ResumeBuilder.document(from: .init(
            personalInfo: person,
            experiences: [gojek, tokopedia, telkom, research, bangkit, gdg, lab],
            education: [university],
            projects: [sehatin, kirana],
            achievements: [distinction, gemastik],
            certifications: [azure, appleCert, toefl],
            skills: skills
        ))
        let masterResume = Resume(title: "Master Resume", targetPosition: "iOS Engineer", document: master)
        masterResume.isMaster = true

        var grab = master
        grab.sections.removeAll { $0.kind == .organizational }
        grab.summary = "iOS engineer focused on payments and performance. Rebuilt GoPay's confirmation flow in SwiftUI and cut cold-start time by 38%, and ready to do the same for Grab's super app."
        grab.format = ResumeFormat(font: .georgia, accent: .navy, showsWorkArrangement: true, dateStyle: .long)
        if let index = grab.sections.firstIndex(where: { $0.kind == .experience }) {
            grab.sections[index].heading = "Professional Experience"
        }
        let grabResume = Resume(
            title: "Grab Application", targetPosition: "Software Engineer II, iOS",
            jobDescription: applications[0].jobDescription, document: grab
        )

        var traveloka = master
        traveloka.sections.removeAll { $0.kind == .achievements }
        traveloka.format = ResumeFormat(font: .arial, fontSize: 10.5, accent: .teal, paper: .letter)
        let travelokaResume = Resume(
            title: "Traveloka Application", targetPosition: "iOS Engineer",
            jobDescription: applications[1].jobDescription, document: traveloka
        )

        for resume in [masterResume, grabResume, travelokaResume] {
            context.insert(resume)
        }
        addHistory(to: masterResume, in: context)
        applications[0].resume = grabResume
        applications[1].resume = travelokaResume
        [applications[2], applications[4], applications[7]].forEach { $0.resume = masterResume }

        // The profile gained a line after the Master was made, so a suggestion is waiting (FR-042).
        gojek.impacts.append("Mentored 3 interns on SwiftUI architecture and testing")

        // Spread "last edited" over the past weeks so Recent Activity reads like real use.
        for (index, record) in profile.compactMap({ $0 as? any EditableRecord }).enumerated() {
            record.createdAt = .now - day * Double(40 + index)
            record.updatedAt = .now - day * Double(8 + index * 2)
        }
        let edited: [(any EditableRecord, Double)] = [
            (gojek, 0.3), (masterResume, 0.2), (grabResume, 2), (travelokaResume, 6), (kirana, 3),
            (duplicate, 30), (research, 30), (person, 12), (university, 20), (azure, 25),
        ]
        for (record, daysAgo) in edited { record.updatedAt = .now - day * daysAgo }
        for application in applications {
            application.updatedAt = application.applicationDate ?? .now - day * 15
        }

        try? context.save()
    }

    private static func sampleApplications() -> [JobApplication] {
        func application(
            _ company: String, _ position: String, _ status: ApplicationStatus, daysAgo: Double?, _ description: String
        ) -> JobApplication {
            JobApplication(
                company: company, position: position, jobDescription: description,
                applicationDate: daysAgo.map { .now - day * $0 }, status: status
            )
        }
        return [
            application("Grab", "Software Engineer II, iOS", .interview, daysAgo: 18, """
            Build and ship features in the Grab superapp for millions of users across Southeast Asia. \
            3+ years of iOS experience, strong Swift with UIKit and SwiftUI, experience with modular \
            architecture, performance tuning, and A/B testing.
            """),
            application("Traveloka", "iOS Engineer", .assessment, daysAgo: 12, """
            Own booking flows end to end in the Traveloka app. Experience with Swift, SwiftUI, \
            offline-first data, and working closely with product and design.
            """),
            application("Shopee", "iOS Engineer, Payments", .applied, daysAgo: 5, """
            Build ShopeePay features for a large regional user base. Strong Swift, secure payment flows, \
            and an eye for reliability.
            """),
            application("Bukalapak", "Senior iOS Engineer", .rejected, daysAgo: 45, """
            Lead iOS initiatives for the marketplace app. 5+ years of iOS experience and mentoring.
            """),
            application("Spotify", "iOS Engineer, Accessibility", .applied, daysAgo: 3, """
            Make Spotify on iOS usable for everyone. Experience with VoiceOver, Dynamic Type, \
            and accessibility audits.
            """),
            application("Stripe", "Mobile Engineer, SDK", .wishlist, daysAgo: nil, """
            Build the Stripe iOS SDK used by thousands of businesses. Strong API design and documentation.
            """),
            application("Ruangguru", "iOS Engineer", .withdrawn, daysAgo: 30, """
            Build learning experiences for millions of Indonesian students.
            """),
            application("Xendit", "Mobile Engineer", .offer, daysAgo: 40, """
            Build payment SDKs and the Xendit dashboard app. Swift and Kotlin welcome.
            """),
            application("Blibli", "iOS Developer", .interview, daysAgo: 9, """
            Ship commerce features in SwiftUI with a focus on performance and quality.
            """),
            application("Apple", "iOS Engineer, Health", .wishlist, daysAgo: nil, """
            Build health features in iOS. Strong Swift and SwiftUI, and care for privacy and design.
            """),
        ]
    }

    /// Websites behind each name, so logos show when lookup is on.
    private static func organizations() -> [Organization] {
        [
            ("Gojek", "gojek.com"), ("PT Gojek Indonesia", "gojek.com"), ("Tokopedia", "tokopedia.com"),
            ("Telkom Indonesia", "telkom.co.id"), ("Telkom University", "telkomuniversity.ac.id"),
            ("Grab", "grab.com"), ("Traveloka", "traveloka.com"), ("Shopee", "shopee.co.id"),
            ("Bukalapak", "bukalapak.com"), ("Spotify", "spotify.com"), ("Stripe", "stripe.com"),
            ("Ruangguru", "ruangguru.com"), ("Xendit", "xendit.co"), ("Blibli", "blibli.com"), ("Apple", "apple.com"),
        ].map { Organization(name: $0.0, domain: $0.1) }
    }

    /// A certificate PDF, a portfolio image, and a reference letter (FR-022).
    private static func documents(certificate: Certification, project: Project, experience: Experience) -> [SupportingDocument] {
        var page = ResumeDocument()
        page.header = ResumeHeader(fullName: "Certificate of Achievement", headline: "Microsoft Certified: Azure AI Fundamentals · Raka Aditya Pratama")
        let pdf = SupportingDocument(
            name: "Azure AI Fundamentals certificate", fileName: "Azure AI Fundamentals.pdf",
            data: ResumeRenderer.pdf(for: page), kind: .certificate
        )
        pdf.certification = certificate

        let image = NSImage(size: CGSize(width: 480, height: 320), flipped: false) { rect in
            NSGradient(colors: [.systemIndigo, .systemTeal])?.draw(in: rect, angle: 35)
            NSAttributedString(string: "Kirana", attributes: [
                .font: NSFont.systemFont(ofSize: 64, weight: .bold), .foregroundColor: NSColor.white,
            ]).draw(at: CGPoint(x: 40, y: 40))
            return true
        }
        let png = image.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) } ?? Data()
        let screens = SupportingDocument(name: "Kirana screens", fileName: "Kirana screens.png", data: png, kind: .portfolio)
        screens.project = project

        let letter = SupportingDocument(
            name: "Tokopedia recommendation letter", fileName: "Tokopedia recommendation letter.txt",
            data: Data("Raka was one of the strongest interns on our iOS team. He shipped a component six teams adopted.".utf8),
            kind: .other
        )
        letter.experience = experience
        return [pdf, screens, letter]
    }

    /// A few versions so History has something to compare.
    private static func addHistory(to resume: Resume, in context: ModelContext) {
        let current = resume.document
        var first = current
        first.summary = "iOS engineer building consumer apps in Swift and SwiftUI."
        first.format.font = .georgia
        var second = current
        if !second.sections.isEmpty, !second.sections[0].entries.isEmpty {
            second.sections[0].entries[0].bullets.removeLast()
        }
        let versions: [(SnapshotReason, String, ResumeDocument, Double)] = [
            (.created, "", first, 9),
            (.checkpoint, "Before the Grab application", second, 4),
            (.exported, "", current, 0.2),
        ]
        for (reason, name, document, daysAgo) in versions {
            let snapshot = ResumeSnapshot(reason: reason, name: name, document: document, createdAt: .now - day * daysAgo)
            context.insert(snapshot)
            snapshot.resume = resume
        }
    }
}
#endif
