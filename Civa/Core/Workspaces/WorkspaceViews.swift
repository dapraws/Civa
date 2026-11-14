//
//  WorkspaceViews.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import SwiftUI

/// A switch asked for from Settings or the Civa menu; the main window confirms and restarts.
@Observable
final class WorkspaceSwitcher {
    static let shared = WorkspaceSwitcher()

    var request: Workspace?
    var error: String?
}

extension View {
    /// "Restart Civa to open …?" Unsaved edits are resolved first; then Civa switches and restarts.
    func workspaceSwitchAlert(_ changes: UnsavedChangesGuard) -> some View {
        modifier(WorkspaceSwitchAlert(changes: changes))
    }
}

private struct WorkspaceSwitchAlert: ViewModifier {
    let changes: UnsavedChangesGuard
    @State private var switcher = WorkspaceSwitcher.shared

    func body(content: Content) -> some View {
        let name = switcher.request?.displayName ?? ""
        content
            .alert(
                Text("Restart Civa to open “\(name)”?"),
                isPresented: Binding(get: { switcher.request != nil }, set: { if !$0 { switcher.request = nil } })
            ) {
                Button("Restart") {
                    guard let target = switcher.request else { return }
                    switcher.request = nil
                    changes.perform { restart(into: target) }
                }
                Button("Not Now", role: .cancel) { switcher.request = nil }
            } message: {
                Text("Civa closes and opens again with this workspace's data.")
            }
            .alert(
                "Couldn't Restart Civa",
                isPresented: Binding(get: { switcher.error != nil }, set: { if !$0 { switcher.error = nil } })
            ) {
                Button("OK") { switcher.error = nil }
            } message: {
                Text(switcher.error ?? "")
            }
    }

    private func restart(into target: Workspace) {
        let registry = WorkspaceRegistry.shared
        let previous = registry.currentID
        registry.switchTo(target.id)
        AppRelauncher.relaunch { error in
            // Stay where we are, preferences included.
            registry.switchTo(previous)
            WorkspaceSwitcher.shared.error = error.localizedDescription
        }
    }
}

/// Civa ▸ Switch Workspace, with a check by the open one.
struct WorkspaceMenu: View {
    @Environment(\.openWindow) private var openWindow
    private let registry = WorkspaceRegistry.shared

    var body: some View {
        Menu("Switch Workspace") {
            ForEach(registry.all) { workspace in
                Toggle(workspace.displayName, isOn: Binding(
                    get: { workspace.id == registry.currentID },
                    set: { isOn in
                        guard isOn, workspace.id != registry.currentID else { return }
                        WorkspaceSwitcher.shared.request = workspace
                        openWindow(id: "main")
                    }
                ))
            }
            Divider()
            Button("Manage Workspaces…") {
                Onboarding.shared.request = .settings
                openWindow(id: "main")
            }
        }
    }
}

/// Settings → Workspaces: the list, New, Rename, Delete (to the Trash), and Switch.
struct WorkspacesSection: View {
    private enum Naming: Identifiable {
        case new, rename(Workspace)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let workspace): workspace.id.uuidString
            }
        }
    }

    private let registry = WorkspaceRegistry.shared
    @State private var naming: Naming?
    @State private var name = ""
    @State private var nameError: String?
    @State private var deleting: Workspace?

    var body: some View {
        Section {
            ForEach(registry.all) { workspace in
                row(workspace)
            }
            Button("New Workspace…", systemImage: "plus") {
                name = ""
                naming = .new
            }
            .civaButton(.textLink)
        } header: {
            SectionTitle("Workspaces")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Each workspace keeps its own profile, resumes, applications, documents, Ovi, and Claude permissions. Anyone using this Mac account can open any workspace; for privacy, give each person their own Mac account.")
                #if DEBUG
                if DataMode.current != .real {
                    Text("This debug run uses \(DataMode.current.title). Workspaces open their data with My Real Data.")
                }
                #endif
            }
        }
        .alert(
            namingTitle,
            isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })
        ) {
            TextField("Name", text: $name)
            Button(namingButton, action: saveName)
            Button("Cancel", role: .cancel) { naming = nil }
        }
        .alert(
            "Couldn't Save the Name",
            isPresented: Binding(get: { nameError != nil }, set: { if !$0 { nameError = nil } })
        ) {
            Button("OK") { nameError = nil }
        } message: {
            Text(nameError ?? "")
        }
        .confirmationDialog(
            Text("Delete “\(deleting?.displayName ?? "")”?"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Move to Trash", role: .destructive) {
                guard let workspace = deleting else { return }
                deleting = nil
                do { try registry.delete(workspace.id) } catch { nameError = error.localizedDescription }
            }
        } message: {
            Text("Its profile, resumes, applications, and documents move to the Trash. You can put them back from there.")
        }
    }

    private func row(_ workspace: Workspace) -> some View {
        let isCurrent = workspace.id == registry.currentID
        return LabeledContent {
            HStack(spacing: Space.s) {
                if isCurrent {
                    Text("Open").foregroundStyle(Color.textSecondary)
                } else {
                    Button("Switch…") { WorkspaceSwitcher.shared.request = workspace }
                        .civaButton(.textLink)
                }
                Menu {
                    Button("Rename…") {
                        name = workspace.name
                        naming = .rename(workspace)
                    }
                    Button("Delete…", role: .destructive) { deleting = workspace }
                        .disabled(isCurrent)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel(Text("More for \(workspace.displayName)"))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        } label: {
            Text(workspace.displayName)
                .fontWeight(isCurrent ? .semibold : .regular)
        }
    }

    private var namingTitle: Text {
        switch naming {
        case .rename: Text("Rename Workspace")
        default: Text("New Workspace")
        }
    }

    private var namingButton: LocalizedStringKey {
        if case .rename = naming { "Rename" } else { "Create" }
    }

    private func saveName() {
        guard let current = naming else { return }
        naming = nil
        do {
            switch current {
            case .new:
                let created = try registry.create(name: name)
                // Offer to open it right away.
                WorkspaceSwitcher.shared.request = created
            case .rename(let workspace):
                try registry.rename(workspace.id, to: name)
            }
        } catch {
            nameError = error.localizedDescription
        }
    }
}

#Preview("Light") {
    Form { WorkspacesSection() }
        .civaForm()
        .frame(width: 700, height: 400)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    Form { WorkspacesSection() }
        .civaForm()
        .frame(width: 700, height: 400)
        .preferredColorScheme(.dark)
}
