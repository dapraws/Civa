//
//  DashboardView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// Home page: a short summary of the profile and applications, not an analytics page (FR-002).
struct DashboardView: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(AppNavigation.self) private var navigation

    @Query private var personalInfo: [PersonalInfo]
    @Query private var experiences: [Experience]
    @Query private var education: [Education]
    @Query private var projects: [Project]
    @Query private var achievements: [Achievement]
    @Query private var certifications: [Certification]
    @Query private var skills: [Skill]
    @Query private var applications: [JobApplication]
    @Query(sort: \Resume.updatedAt, order: .reverse) private var resumes: [Resume]
    @Query(filter: #Predicate<ResumeSnapshot> { $0.reasonRaw == "exported" }) private var exports: [ResumeSnapshot]
    @Query(filter: #Predicate<ClaudeProposal> { $0.statusRaw == "pending" }) private var claudeProposals: [ClaudeProposal]
    @Query(filter: #Predicate<ClaudeRequest> { $0.statusRaw == "pending" || $0.statusRaw == "failed" })
    private var claudeRequests: [ClaudeRequest]
    @State private var isSettingUpClaude = false
    @State private var showsAllNeeds = false

    var body: some View {
        let summary = DashboardSummary(
            personalInfo: personalInfo,
            experiences: experiences,
            education: education,
            projects: projects,
            achievements: achievements,
            certifications: certifications,
            skills: skills,
            applications: applications,
            resumes: resumes,
            pendingClaude: claudeProposals.count + claudeRequests.count
        )
        ScrollView {
            PageFrame(maxWidth: Size.dashboardMaxWidth) {
                VStack(alignment: .leading, spacing: Space.xl) {
                    PageHeader(String(localized: "Dashboard")) {
                        ImportMenu(showsTitle: true)
                            .menuStyle(.button)
                            .civaButton(.secondary)
                            .fixedSize()
                        Button("New Resume", systemImage: "plus", action: newResume)
                            .civaButton(.primary)
                    }
                    if summary.isEmpty {
                        emptyState
                    } else {
                        GettingStartedCard(steps: gettingStarted(summary), onShowMe: showMe)
                        RatioRow(ratios: [3, 2], spacing: Space.m) {
                            continueTile(summary.continueResume)
                            profileTile(summary)
                        }
                        pipeline(summary)
                        RatioRow(ratios: [1, 1], spacing: Space.m) {
                            needsYou(summary)
                            recent(summary)
                        }
                    }
                }
            }
        }
        .background(Color.canvas)
        .onAppear {
            // First launch with nothing saved yet.
            if summary.isEmpty, !UserDefaults.standard.bool(forKey: Onboarding.welcomeShownKey) {
                Onboarding.shared.showsWelcome = true
            }
        }
        .sheet(isPresented: $isSettingUpClaude) { ClaudeSetupSheet() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            EmptyStateView(
                symbol: AppSection.careerProfile.systemImage,
                title: "Start your Career Profile",
                message: "Add your details once, then reuse them for every resume. Everything stays on this Mac."
            )
            HStack(spacing: Space.s) {
                Button("Add Personal Information") { open(.personal) }
                    .civaButton(.primary, size: .large)
                Button("Add Experience", action: addExperience)
                    .civaButton(.secondary, size: .large)
                ImportMenu(showsTitle: true)
                    .menuStyle(.button)
                    .civaButton(.secondary, size: .large)
                    .fixedSize()
            }
        }
    }

    // MARK: Tiles (DESIGN.md §8.2)

    @ViewBuilder
    private func continueTile(_ resume: Resume?) -> some View {
        Group {
            if let resume {
                HStack(alignment: .top, spacing: Space.l) {
                    ResumeCard.thumbnail(resume.document)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 62, height: 80)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 2))
                        .paperShadow()
                        .accessibilityLabel(Text(resume.displayTitle))
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Continue where you left off")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        Text(resume.displayTitle)
                            .font(.sectionTitle)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text("Resume · edited \(resume.updatedAt, format: .relative(presentation: .named))")
                            .font(.callout)
                            .foregroundStyle(Color.textSecondary)
                        Button("Open in Editor") { openResume(resume) }
                            .civaButton(.textLink)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Make your first resume")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text("Build it from your Career Profile and see the PDF as you edit.")
                        .foregroundStyle(Color.textSecondary)
                    Button("New Resume", action: newResume)
                        .civaButton(.secondary)
                }
            }
        }
        .tile()
    }

    private func profileTile(_ summary: DashboardSummary) -> some View {
        let total = ProfileCategory.allCases.count
        let filled = summary.filledCategories.count
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Career Profile")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            Text("\(filled) of \(total)")
                .font(.statNumber)
                .foregroundStyle(Color.textPrimary)
            CivaProgressBar(value: Double(filled) / Double(total), label: String(localized: "\(filled) of \(total) sections filled in"))
            if let missing = summary.missingCategories.first {
                HStack(spacing: Space.xs) {
                    Text("\(missing.title) missing").foregroundStyle(Color.textSecondary)
                    Button("Add") { open(missing) }.civaButton(.textLink)
                }
                .font(.callout)
            }
            if summary.needsReviewCount > 0 {
                HStack(spacing: Space.xs) {
                    Text("^[\(summary.needsReviewCount) record](inflect: true) need review").foregroundStyle(Color.textSecondary)
                    Button("Review", action: openFirstNeedsReview).civaButton(.textLink)
                }
                .font(.callout)
            }
        }
        .tile()
    }

    private func pipeline(_ summary: DashboardSummary) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(summary.pipeline.enumerated()), id: \.element.status) { index, item in
                if index > 0 { Rectangle().fill(Color.hairline).frame(width: 1) }
                PipelineCell(status: item.status, count: item.count) {
                    go {
                        navigation.applicationStatusFilter = item.status
                        navigation.section = .applications
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
        .clipShape(.rect(cornerRadius: Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
    }

    private func needsYou(_ summary: DashboardSummary) -> some View {
        let rows = showsAllNeeds ? summary.needsYou : Array(summary.needsYou.prefix(DashboardSummary.needsYouLimit))
        return CivaSection("Needs you") {
            if rows.isEmpty {
                Text("Nothing needs you right now.")
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Space.m)
                    .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                needsRow(row)
            }
            if !showsAllNeeds, summary.needsYou.count > DashboardSummary.needsYouLimit {
                Button("Show all") { showsAllNeeds = true }
                    .civaButton(.textLink)
                    .padding(.horizontal, Space.m)
                    .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func needsRow(_ row: DashboardSummary.NeedsYou) -> some View {
        switch row {
        case .claude(let count):
            HStack(spacing: Space.s) {
                Image(systemName: "sparkles").foregroundStyle(Color.claude).accessibilityHidden(true)
                Text("^[\(count) item](inflect: true) from Claude").foregroundStyle(Color.claudeText)
                Spacer(minLength: Space.s)
                Button("Review") {
                    go {
                        navigation.aiActivityTab = claudeProposals.isEmpty ? .requests : .suggestions
                        navigation.section = .aiActivity
                    }
                }
                .civaButton(.textLink, color: .claudeText)
            }
            .padding(.horizontal, Space.m)
            .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
        case .review(let count):
            needsLine(Text("^[\(count) record](inflect: true) to confirm"), action: "Review", run: openFirstNeedsReview)
        case .usesMaster(let id, let company):
            needsLine(Text("\(company) uses your Master resume"), action: "Tailor") { openApplication(id) }
        case .notApplied(let id, let company):
            needsLine(Text("\(company) · not applied yet"), action: "Open") { openApplication(id) }
        }
    }

    private func needsLine(_ text: Text, action: LocalizedStringKey, run: @escaping () -> Void) -> some View {
        HStack(spacing: Space.s) {
            text.foregroundStyle(Color.textPrimary).lineLimit(1)
            Spacer(minLength: Space.s)
            Button(action, action: run).civaButton(.textLink)
        }
        .padding(.horizontal, Space.m)
        .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
    }

    private func recent(_ summary: DashboardSummary) -> some View {
        CivaSection("Recent") {
            if summary.recentActivity.isEmpty {
                Text("Nothing yet.")
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Space.m)
                    .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
            }
            ForEach(summary.recentActivity) { activity in
                HStack(spacing: Space.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title).foregroundStyle(Color.textPrimary).lineLimit(1)
                        Text(activity.kind).font(.callout).foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: Space.s)
                    Text(activity.date, format: .relative(presentation: .named))
                        .font(.callout)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
            }
        }
    }

    private func gettingStarted(_ summary: DashboardSummary) -> GettingStarted {
        GettingStarted(
            hasNameAndEmail: personalInfo.contains { !$0.fullName.isBlank && !$0.email.isBlank },
            hasBackground: experiences.contains { !$0.needsReview } || education.contains { !$0.needsReview },
            needsReview: summary.needsReviewCount,
            hasResume: !resumes.isEmpty,
            hasExported: !exports.isEmpty,
            hasApplication: !applications.isEmpty,
            claudeConnected: ClaudeBridge.shared.isEnabled
        )
    }

    private func showMe(_ step: GettingStarted.Step) {
        switch step {
        case .personal: open(.personal)
        case .background: open(.professional)
        case .review: openFirstNeedsReview()
        case .resume: go { navigation.section = .resumes }
        case .export:
            // The Master, or the newest resume: Export is in its toolbar.
            let resume = resumes.first(where: \.isMaster) ?? resumes.first
            go {
                navigation.recordToOpen = resume?.id
                navigation.section = .resumes
            }
        case .application:
            go {
                navigation.startsNewRecord = true
                navigation.section = .applications
            }
        case .claude: isSettingUpClaude = true
        }
    }

    private func open(_ category: ProfileCategory) {
        go {
            navigation.profileCategory = category
            navigation.section = .careerProfile
        }
    }

    /// The first record that still needs review, on its own page.
    private func openFirstNeedsReview() {
        let target: (ProfileCategory, AnyHashable, String?)? = if let record = personalInfo.first(where: \.needsReview) {
            (.personal, AnyHashable(record.id), nil)
        } else if let record = experiences.first(where: \.needsReview) {
            (record.kind == .professional ? .professional : .organizational, AnyHashable(record.id), nil)
        } else if let record = education.first(where: \.needsReview) {
            (.education, AnyHashable(record.id), nil)
        } else if let record = projects.first(where: \.needsReview) {
            (.projects, AnyHashable(record.id), nil)
        } else if let record = achievements.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "achievements")
        } else if let record = certifications.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "certifications")
        } else if let record = skills.first(where: \.needsReview) {
            (.other, AnyHashable(record.id), "skills")
        } else {
            nil
        }
        guard let (category, id, otherKind) = target else { return }
        go {
            // Personal Information is a single record with no list to pick from.
            navigation.recordToOpen = category == .personal ? nil : id
            navigation.otherKind = otherKind
            navigation.profileCategory = category
            navigation.section = .careerProfile
        }
    }

    private func newResume() {
        go {
            navigation.startsNewRecord = true
            navigation.section = .resumes
        }
    }

    private func openResume(_ resume: Resume) {
        go {
            navigation.recordToOpen = resume.id
            navigation.section = .resumes
        }
    }

    private func openApplication(_ id: UUID) {
        go {
            navigation.recordToOpen = id
            navigation.section = .applications
        }
    }

    private func addExperience() {
        go {
            navigation.profileCategory = .professional
            navigation.startsNewRecord = true
            navigation.section = .careerProfile
        }
    }

    /// Dashboard never holds unsaved edits, but navigation always goes through the guard.
    private func go(_ action: @escaping () -> Void) {
        changes.perform(action)
    }
}

/// One status in the pipeline strip: its mark and count. Opens Applications filtered to it.
private struct PipelineCell: View {
    let status: ApplicationStatus
    let count: Int
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Space.xs) {
                StatusMark(status)
                Text(count, format: .number)
                    .font(.statNumber)
                    .monospacedDigit()
                    .foregroundStyle(count == 0 ? Color.textTertiary : Color.textPrimary)
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.hover : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .help("Show \(status.title) applications")
        .accessibilityLabel(Text("\(status.title): \(count)"))
    }
}

private extension View {
    /// A Dashboard tile: white, hairline outline, card corners, 16 pt padding.
    func tile() -> some View {
        padding(Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.surface, in: .rect(cornerRadius: Radius.card))
            .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.hairline) }
    }
}

/// Lays its children side by side at fixed width ratios (3:2, 1:1), all as tall as the tallest.
private struct RatioRow: Layout {
    let ratios: [CGFloat]
    let spacing: CGFloat

    private func widths(_ total: CGFloat, count: Int) -> [CGFloat] {
        let ratios = Array(ratios.prefix(count))
        let sum = ratios.reduce(0, +)
        let available = total - spacing * CGFloat(max(count - 1, 0))
        return ratios.map { available * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 720
        let widths = widths(total, count: subviews.count)
        let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

#Preview {
    DashboardView()
    .frame(width: 900, height: 640)
    .previewEnvironment()
}
