//
//  CopyPromptViews.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import AppKit
import SwiftUI

/// "Copy Prompt": a neutral text link beside the Claude one (not Claude orange: it works with any
/// AI). It shows the prompt and what it includes before anything reaches the clipboard.
struct CopyPromptButton: View {
    /// Built when clicked, from what's on screen now (saved or not).
    let makePrompt: () -> CopyPrompt

    @State private var prompt: CopyPrompt?

    var body: some View {
        Button("Copy Prompt") { prompt = makePrompt() }
            .civaButton(.textLink, color: .textPrimary)
            .fixedSize()
            .help("A prompt for ChatGPT, Gemini, or another AI, filled with this content")
            .sheet(item: Binding(get: { prompt.map(PromptItem.init) }, set: { prompt = $0?.prompt })) { item in
                CopyPromptSheet(prompt: item.prompt)
            }
    }

    private struct PromptItem: Identifiable {
        let prompt: CopyPrompt
        var id: String { prompt.text }
    }
}

/// The prompt, what goes with it and what doesn't, and Copy.
struct CopyPromptSheet: View {
    let prompt: CopyPrompt

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                SectionTitle(prompt.title)
                Text("Paste it into ChatGPT, Gemini, Claude on the web, or any AI you use. Civa sends nothing itself.")
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(alignment: .top, spacing: Space.xl) {
                list("Includes", prompt.includes, symbol: "checkmark", color: .success)
                list("Leaves out", prompt.excludes, symbol: "minus", color: .textSecondary)
            }
            ScrollView {
                Text(prompt.text)
                    .font(.callout.monospaced())
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.m)
            }
            .frame(height: 240)
            .background(Color.surface, in: .rect(cornerRadius: Radius.control))
            .overlay { RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Color.fieldBorder) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .civaButton(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(copied ? "Copied" : "Copy Prompt", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
                    .civaButton(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 560)
        .background(Color.canvas)
    }

    private func list(_ title: LocalizedStringKey, _ items: [String], symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                } icon: {
                    Image(systemName: symbol).foregroundStyle(color)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}

#Preview("Light") {
    CopyPromptSheet(prompt: .improveBullets(role: "iOS Engineer", organization: "Gojek", bullets: ["Responsible for payments", "Helped the team ship"]))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    CopyPromptSheet(prompt: .improveBullets(role: "iOS Engineer", organization: "Gojek", bullets: ["Responsible for payments"]))
        .preferredColorScheme(.dark)
}
