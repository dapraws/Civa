//
//  DashboardSummary.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// What the Dashboard shows, computed from saved records (FR-002).
struct DashboardSummary {
    struct Activity: Identifiable {
        let id: UUID
        let title: String
        let kind: String
        let date: Date
    }

    /// Profile categories with at least one record.
    let filledCategories: Set<ProfileCategory>
    let needsReviewCount: Int
    /// Most recently updated records first.
    let recentActivity: [Activity]
    /// Every status in pipeline order, with how many applications have it.
    let applicationCounts: [(status: ApplicationStatus, count: Int)]

    var missingCategories: [ProfileCategory] {
        ProfileCategory.allCases.filter { !filledCategories.contains($0) }
    }

    var applicationTotal: Int {
        applicationCounts.reduce(0) { $0 + $1.count }
    }

    var isEmpty: Bool {
        filledCategories.isEmpty && applicationTotal == 0
    }

    init(
        personalInfo: [PersonalInfo],
        experiences: [Experience],
        education: [Education],
        projects: [Project],
        achievements: [Achievement],
        certifications: [Certification],
        skills: [Skill],
        applications: [JobApplication],
        recentLimit: Int = 5
    ) {
        let professional = experiences.filter { $0.kind == .professional }
        let organizational = experiences.filter { $0.kind == .organizational }
        var filled: Set<ProfileCategory> = []
        if personalInfo.contains(where: { !$0.fullName.isBlank }) { filled.insert(.personal) }
        if !professional.isEmpty { filled.insert(.professional) }
        if !education.isEmpty { filled.insert(.education) }
        if !organizational.isEmpty { filled.insert(.organizational) }
        if !projects.isEmpty { filled.insert(.projects) }
        if !(achievements.isEmpty && certifications.isEmpty && skills.isEmpty) { filled.insert(.other) }
        filledCategories = filled

        needsReviewCount = personalInfo.count(where: \.needsReview)
            + experiences.count(where: \.needsReview)
            + education.count(where: \.needsReview)
            + projects.count(where: \.needsReview)
            + achievements.count(where: \.needsReview)
            + certifications.count(where: \.needsReview)
            + skills.count(where: \.needsReview)

        func activity<M: EditableRecord>(_ records: [M], kind: String) -> [Activity] where M.ID == UUID {
            records.map { Activity(id: $0.id, title: $0.displayTitle, kind: kind, date: $0.updatedAt) }
        }
        let activities = activity(personalInfo, kind: ProfileCategory.personal.title)
            + activity(professional, kind: ProfileCategory.professional.title)
            + activity(organizational, kind: ProfileCategory.organizational.title)
            + activity(education, kind: ProfileCategory.education.title)
            + activity(projects, kind: String(localized: "Project"))
            + activity(achievements, kind: String(localized: "Achievement"))
            + activity(certifications, kind: String(localized: "Certification"))
            + activity(skills, kind: String(localized: "Skill"))
            + activity(applications, kind: String(localized: "Application"))
        recentActivity = Array(activities.sorted { $0.date > $1.date }.prefix(recentLimit))

        applicationCounts = ApplicationStatus.allCases.map { status in
            (status, applications.count(where: { $0.status == status }))
        }
    }
}
