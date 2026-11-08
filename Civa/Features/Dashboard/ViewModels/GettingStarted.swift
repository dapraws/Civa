//
//  GettingStarted.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// The Dashboard's Getting Started steps. Worked out from saved data, never stored, so they tick
/// themselves and stay right after something is deleted.
struct GettingStarted {
    enum Step: Hashable {
        case personal, background, review, resume, export, application, claude
    }

    struct Item: Identifiable {
        let step: Step
        let isDone: Bool
        var id: Step { step }
        /// Connecting Claude is offered, never needed.
        var isOptional: Bool { step == .claude }
    }

    let items: [Item]

    init(
        hasNameAndEmail: Bool = false, hasBackground: Bool = false, needsReview: Int = 0, hasResume: Bool = false,
        hasExported: Bool = false, hasApplication: Bool = false, claudeConnected: Bool = false
    ) {
        var items = [Item(step: .personal, isDone: hasNameAndEmail), Item(step: .background, isDone: hasBackground)]
        // Only while imported records wait; it has nothing to say otherwise.
        if needsReview > 0 { items.append(Item(step: .review, isDone: false)) }
        items += [
            Item(step: .resume, isDone: hasResume),
            Item(step: .export, isDone: hasExported),
            Item(step: .application, isDone: hasApplication),
            Item(step: .claude, isDone: claudeConnected),
        ]
        self.items = items
    }

    var requiredCount: Int { items.count { !$0.isOptional } }
    var doneCount: Int { items.count { !$0.isOptional && $0.isDone } }
    var isComplete: Bool { doneCount == requiredCount }
}
