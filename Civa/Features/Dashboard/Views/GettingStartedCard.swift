//
//  GettingStartedCard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// The Dashboard checklist: what's left to get a first resume out, each with a way there.
/// Hidden with Hide; Help → Show Getting Started brings it back.
struct GettingStartedCard: View {
    let steps: GettingStarted
    let onShowMe: (GettingStarted.Step) -> Void

    @AppStorage(Onboarding.checklistHiddenKey) private var isHidden = false

    var body: some View {
        if !isHidden {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(steps.isComplete ? "Getting started" : "Getting started · \(steps.doneCount) of \(steps.requiredCount)")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Hide") { isHidden = true }
                        .civaButton(.textLink)
                        .help("Hide this list. Help → Show Getting Started brings it back.")
                }
                CivaSection {
                    if steps.isComplete {
                        Label("You're all set. Everything Civa does is now one click away.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.success)
                            .padding(.horizontal, Space.m)
                            .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
                    }
                    ForEach(steps.items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: GettingStarted.Item) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : item.isOptional ? "sparkles" : "circle")
                .foregroundStyle(item.isDone ? Color.success : item.isOptional ? Color.claude : Color.textTertiary)
                .accessibilityLabel(item.isDone ? "Done" : "Not done")
            Text(title(item.step))
                .foregroundStyle(item.isDone ? Color.textSecondary : Color.textPrimary)
            if item.isOptional {
                Text("Optional").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if !item.isDone {
                Button("Start") { onShowMe(item.step) }
                    .civaButton(.textLink)
            }
        }
        .padding(.horizontal, Space.m)
        .frame(maxWidth: .infinity, minHeight: Size.sectionRow, alignment: .leading)
    }

    private func title(_ step: GettingStarted.Step) -> LocalizedStringKey {
        switch step {
        case .personal: "Add your name and email"
        case .background: "Add an experience or education"
        case .review: "Confirm imported records"
        case .resume: "Make your first resume"
        case .export: "Export a resume as PDF"
        case .application: "Track a job application"
        case .claude: "Connect Claude Desktop"
        }
    }
}

#Preview {
    GettingStartedCard(steps: GettingStarted(hasNameAndEmail: true, needsReview: 2, hasResume: true)) { _ in }
        .padding()
        .frame(width: 600)
}
