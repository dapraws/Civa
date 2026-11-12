//
//  ResumeCard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftData
import SwiftUI

/// A resume in the gallery (DESIGN.md §7.9): its first page, name, and target position. The
/// Master carries the Master tag.
struct ResumeCard: View {
    let resume: Resume
    /// Career Profile changes this resume doesn't have yet (FR-042).
    var suggestionCount = 0

    @Query(filter: #Predicate<ClaudeProposal> { $0.kindRaw == "resumeEdit" && $0.statusRaw == "pending" })
    private var claudeProposals: [ClaudeProposal]

    var body: some View {
        let document = resume.document
        let paper = document.format.paper.size
        VStack(alignment: .leading, spacing: 10) {
            Self.thumbnail(document)
                .resizable()
                .aspectRatio(paper.width / paper.height, contentMode: .fit)
                .background(.white)
                .paperCard()
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        let claudeCount = claudeProposals.filter { $0.targetID == resume.id }.count
                        if claudeCount > 0 {
                            ClaudeCount(count: claudeCount)
                        }
                        if suggestionCount > 0 {
                            CountTag(count: suggestionCount, systemImage: "arrow.triangle.2.circlepath")
                                .help("\(suggestionCount) suggested changes from your Career Profile")
                        }
                    }
                    .padding(6)
                }
            VStack(alignment: .leading, spacing: 2) {
                if resume.isMaster || resume.isClaudeDraft {
                    HStack(spacing: Space.xs) {
                        if resume.isMaster { CivaTag(.master) }
                        if resume.isClaudeDraft { CivaTag(.claude, title: "Draft from Claude") }
                    }
                    .padding(.bottom, 2)
                }
                Text(resume.displayTitle)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let edited = resume.updatedAt.formatted(date: .abbreviated, time: .omitted)
        return resume.targetPosition.isBlank ? edited : "\(resume.targetPosition) · \(edited)"
    }

    // ponytail: renders the PDF on every redraw (~5 ms each); cache by updatedAt if galleries get large.
    static func thumbnail(_ document: ResumeDocument) -> Image {
        let size = document.format.paper.size
        // Keep the document alive while its page draws.
        let pdf = PDFDocument(data: ResumeRenderer.pdf(for: document))
        let image = pdf?.page(at: 0)?.thumbnail(of: CGSize(width: size.width, height: size.height), for: .mediaBox)
        return Image(nsImage: image ?? NSImage())
    }
}

#Preview {
    ResumeCard(resume: Resume(title: "iOS Developer Resume", targetPosition: "iOS Developer", document: .blank))
        .frame(width: 200)
        .padding()
        .previewEnvironment()
}
