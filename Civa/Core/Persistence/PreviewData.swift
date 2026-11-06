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
    /// In-memory store with sample records, for SwiftUI previews.
    static let preview: ModelContainer = {
        let container = try! ModelContainer.civa(inMemory: true)
        let context = container.mainContext

        let swift = Skill(name: "Swift", category: "Languages")
        let swiftUI = Skill(name: "SwiftUI", category: "Frameworks")
        let figma = Skill(name: "Figma", category: "Tools", status: .needsReview)

        let current = Experience(
            kind: .professional,
            organization: "Acme",
            role: "iOS Engineer",
            location: "Jakarta",
            start: YearMonth(year: 2024, month: 3),
            isCurrent: true,
            details: "Built the onboarding flow and the offline sync layer.",
            impacts: ["Cut onboarding drop-off by 18%"],
            customFields: [CustomField(name: "Team Size", value: "6")]
        )
        current.skills = [swift, swiftUI]
        let internship = Experience(
            kind: .professional,
            organization: "Globex",
            role: "Mobile Intern",
            start: YearMonth(year: 2023, month: 6),
            end: YearMonth(year: 2023, month: 12),
            status: .needsReview
        )
        let academy = Experience(
            kind: .organizational,
            organization: "Apple Developer Academy",
            role: "Learner",
            start: YearMonth(year: 2025, month: 3),
            isCurrent: true
        )
        let degree = Education(
            institution: "Universitas Indonesia",
            degree: "Bachelor of Computer Science",
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
        project.skills = [swift, swiftUI, figma]
        let award = Achievement(title: "Best Pitching Team", issuer: "Apple Developer Academy", date: YearMonth(year: 2025, month: 8))
        award.experience = academy

        let records: [any PersistentModel] = [
            PersonalInfo(fullName: "Alex Morgan", headline: "iOS Engineer", email: "alex@example.com", location: "Jakarta"),
            current, internship, academy, degree, project, award,
            Certification(name: "App Development with Swift", issuer: "Apple", issued: YearMonth(year: 2024, month: 5)),
            JobApplication(company: "Northwind", position: "iOS Engineer", applicationDate: .now.addingTimeInterval(-86_400 * 12), status: .interview),
            JobApplication(company: "Contoso", position: "Mobile Engineer", applicationDate: .now.addingTimeInterval(-86_400 * 5), status: .applied),
            JobApplication(company: "Fabrikam", position: "Senior iOS Engineer"),
        ]
        records.forEach { context.insert($0) }
        try! context.save()
        return container
    }()
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
