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
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if steps.isComplete {
                        Label("You're all set. Everything Civa does is now one click away.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        ProgressView(value: Double(steps.doneCount), total: Double(steps.requiredCount)) {
                            Text("\(steps.doneCount) of \(steps.requiredCount) done")
                        }
                    }
                    ForEach(steps.items) { item in
                        row(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            } label: {
                HStack {
                    Label("Getting Started", systemImage: "flag.checkered")
                    Spacer()
                    Button("Hide") { isHidden = true }
                        .buttonStyle(.link)
                        .help("Hide this list. Help → Show Getting Started brings it back.")
                }
            }
        }
    }

    private func row(_ item: GettingStarted.Item) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : item.isOptional ? "sparkles" : "circle")
                .foregroundStyle(item.isDone ? AnyShapeStyle(.green) : item.isOptional ? AnyShapeStyle(Color.claude) : AnyShapeStyle(.secondary))
                .accessibilityLabel(item.isDone ? "Done" : "Not done")
            Text(title(item.step))
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .strikethrough(item.isDone)
            if item.isOptional {
                Text("Optional").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !item.isDone {
                Button("Show Me") { onShowMe(item.step) }
                    .buttonStyle(.link)
            }
        }
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
