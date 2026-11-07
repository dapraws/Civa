//
//  ResumeCard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import PDFKit
import SwiftUI

/// A resume in the gallery: its first page, name, and target position. The Master is outlined.
struct ResumeCard: View {
    let resume: Resume
    /// Career Profile changes this resume doesn't have yet (FR-042).
    var suggestionCount = 0

    var body: some View {
        let document = resume.document
        let paper = document.format.paper.size
        VStack(alignment: .leading, spacing: 10) {
            thumbnail(document)
                .resizable()
                .aspectRatio(paper.width / paper.height, contentMode: .fit)
                .background(.white)
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(resume.isMaster ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: resume.isMaster ? 2 : 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .overlay(alignment: .topTrailing) {
                    if suggestionCount > 0 {
                        Label("\(suggestionCount)", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(.white)
                            .background(.tint, in: .capsule)
                            .padding(6)
                            .help("\(suggestionCount) suggested changes from your Career Profile")
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                if resume.isMaster {
                    Label("Master Resume", systemImage: "crown")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                if resume.isClaudeDraft {
                    Label("Draft from Claude", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Text(resume.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
    private func thumbnail(_ document: ResumeDocument) -> Image {
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
}
