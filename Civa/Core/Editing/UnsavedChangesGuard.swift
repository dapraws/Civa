//
//  UnsavedChangesGuard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Observation
import SwiftUI

/// Holds the active editor and makes every navigation resolve its unsaved changes first (FR-003).
@Observable
final class UnsavedChangesGuard {
    enum Resolution {
        case save, discard, cancel
    }

    private struct Pending {
        let action: () -> Void
        let onCancel: () -> Void
    }

    var active: (any EditSession)?
    private var pending: Pending?

    var hasUnsavedChanges: Bool { active?.isDirty ?? false }
    var isPrompting: Bool { pending != nil }

    /// Runs `action` once the active editor is resolved: right away when nothing is unsaved,
    /// otherwise after the user picks Save or Don't Save. Cancel runs `onCancel` instead.
    func perform(onCancel: @escaping () -> Void = {}, _ action: @escaping () -> Void) {
        guard let active, active.isDirty else {
            active?.discard()  // drops a new record the user never touched
            self.active = nil
            action()
            return
        }
        pending = Pending(action: action, onCancel: onCancel)
    }

    func resolve(_ resolution: Resolution) {
        guard let pending else { return }
        self.pending = nil
        switch resolution {
        case .save:
            guard active?.save() == true else { return pending.onCancel() }  // errors stay visible
        case .discard:
            active?.discard()
        case .cancel:
            return pending.onCancel()
        }
        active = nil
        pending.action()
    }

    /// Binding for a selection control (sidebar, tabs, list). `value` changes only once unsaved
    /// changes are resolved; meanwhile the control shows the clicked choice through `pending`,
    /// which Cancel clears. `apply` replaces the plain assignment when more needs to happen.
    func selection<Value: Equatable>(
        _ value: Binding<Value>,
        pending: Binding<Value?>,
        apply: ((Value) -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { pending.wrappedValue ?? value.wrappedValue },
            set: { newValue in
                guard newValue != value.wrappedValue else { return pending.wrappedValue = nil }
                pending.wrappedValue = newValue
                self.perform(onCancel: { pending.wrappedValue = nil }) {
                    pending.wrappedValue = nil
                    if let apply { apply(newValue) } else { value.wrappedValue = newValue }
                }
            }
        )
    }
}

extension View {
    /// The standard "save changes" alert. Attach once, at the root.
    func unsavedChangesAlert(_ changes: UnsavedChangesGuard) -> some View {
        alert(
            Text("Do you want to save the changes to “\(changes.active?.title ?? "")”?"),
            isPresented: Binding(
                get: { changes.isPrompting },
                set: { if !$0 { changes.resolve(.cancel) } }
            )
        ) {
            Button("Save") { changes.resolve(.save) }
            Button("Don't Save", role: .destructive) { changes.resolve(.discard) }
            Button("Cancel", role: .cancel) { changes.resolve(.cancel) }
        } message: {
            Text("Your changes will be lost if you don't save them.")
        }
    }
}
