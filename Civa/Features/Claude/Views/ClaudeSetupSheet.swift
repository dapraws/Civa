//
//  ClaudeSetupSheet.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Guided setup for Claude Desktop (FR-070): what's shared, connecting, restarting Claude, and a
/// test question. Optional, and it can be reopened from Settings.
struct ClaudeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private var bridge = ClaudeBridge.shared
    @State private var startedAt = Date.now
    @State private var isConnected = ClaudeBridge.shared.isEnabled
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Connect Claude Desktop", systemImage: "sparkles")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.claude)
                        Text("Claude can help you rewrite bullet points, write a summary, and tailor a resume to a job. Civa works fully without it.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Label("Claude reads only the categories you allow. Nothing is shared until you choose.", systemImage: "lock")
                    Label("Anything Claude suggests waits for your approval in Civa.", systemImage: "checkmark.shield")
                    Label("Civa needs to be open while you use Claude with it.", systemImage: "macwindow")
                }

                Section("How It Works") {
                    ClaudeHowItWorks().padding(.vertical, 4)
                }

                Section {
                    if ClaudeDesktopConfig.isClaudeInstalled {
                        HStack {
                            Text(isConnected ? "Claude Desktop knows about Civa." : "Civa adds itself to Claude Desktop's settings. You'll be asked to allow it once.")
                            Spacer()
                            if isConnected {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityLabel("Done")
                            } else {
                                Button("Connect…", action: connect)
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        if let error { FieldError(error) }
                    } else {
                        Text("Claude Desktop isn't installed on this Mac.")
                        Button("Get Claude Desktop") { openURL(URL(string: "https://claude.ai/download")!) }
                    }
                } header: {
                    Text("1. Connect")
                }

                if isConnected {
                    ClaudePermissionsSection()
                }

                Section {
                    Text("Quit Claude Desktop with ⌘Q, then open it again so it finds Civa.")
                    Button("Open Claude Desktop") { ClaudeDesktopConfig.openClaude() }
                        .disabled(!isConnected)
                } header: {
                    Text("2. Restart Claude Desktop")
                }

                Section {
                    Text("In Claude Desktop, ask “Is Civa connected?” and allow Civa's tool when Claude asks.")
                    HStack {
                        if let last = bridge.lastConnected, last >= startedAt {
                            Label("Claude Desktop reached Civa \(last.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            ProgressView().controlSize(.small)
                            Text("Waiting for Claude Desktop…").foregroundStyle(.secondary)
                        }
                    }
                    .opacity(isConnected ? 1 : 0.4)
                } header: {
                    Text("3. Test")
                } footer: {
                    Text("You can change what Claude may use any time in Settings.")
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(isConnected ? "Done" : "Not Now") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 560, height: 680)
    }

    private func connect() {
        guard let executable = Bundle.main.executablePath else { return }
        do {
            guard try ClaudeDesktopConfig.update(prompt: String(localized: "Allow"), { try ClaudeDesktopConfig.adding(executable: executable, to: $0) }) else { return }
            error = nil
            startedAt = .now
            bridge.enable()
            isConnected = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Settings → Claude Desktop: status, setup, and disconnecting (FR-070).
struct ClaudeSettingsSection: View {
    private var bridge = ClaudeBridge.shared
    @State private var isSettingUp = false
    @State private var isConfirmingDisconnect = false
    @State private var error: String?

    var body: some View {
        Group {
            statusSection
            if bridge.isEnabled {
                ClaudePermissionsSection()
                ClaudeRecentActivitySection()
            }
        }
        .sheet(isPresented: $isSettingUp) { ClaudeSetupSheet() }
        .confirmationDialog("Disconnect Claude Desktop?", isPresented: $isConfirmingDisconnect) {
            Button("Disconnect", role: .destructive, action: disconnect)
        } message: {
            Text("Civa stops answering Claude and removes itself from Claude Desktop's settings. You'll be asked to allow that change.")
        }
    }

    private var statusSection: some View {
        Section {
            if bridge.isEnabled {
                LabeledContent("Status") {
                    if let problem = bridge.problem {
                        Text(problem).foregroundStyle(.red)
                    } else if let last = bridge.lastConnected {
                        Text("Connected · last used \(last.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Waiting for Claude Desktop")
                    }
                }
                HStack {
                    Button("Run Setup Again…") { isSettingUp = true }
                    Spacer()
                    Button("Disconnect…", role: .destructive) { isConfirmingDisconnect = true }
                }
            } else {
                HStack {
                    Text("Not connected")
                    Spacer()
                    Button("Set Up…") { isSettingUp = true }
                }
            }
            if let error { FieldError(error) }
        } header: {
            Text("Claude Desktop")
        } footer: {
            Text("Optional. Claude reads only what you allow, and its suggestions wait for your approval. Civa works fully without it.")
        }
    }

    private func disconnect() {
        bridge.disable()
        do {
            _ = try ClaudeDesktopConfig.update(prompt: String(localized: "Allow"), { try ClaudeDesktopConfig.removing(from: $0) })
            error = nil
        } catch {
            // Civa already stopped answering, so Claude can't reach it either way.
            self.error = error.localizedDescription
        }
    }
}

#Preview("Sheet") {
    ClaudeSetupSheet()
}

#Preview("Settings") {
    Form { ClaudeSettingsSection() }.formStyle(.grouped).frame(width: 520)
}
