//
//  ProofSeal.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import QuickLook
import SwiftUI

/// The Verified seal on a record with a proof link or an attached document. Clicking opens the proof.
struct ProofSeal: View {
    let proof: Proof
    /// Rows show the seal alone; editors add the word.
    var showsTitle = false

    @Environment(\.openURL) private var openURL
    @State private var previewURL: URL?

    var body: some View {
        Button(action: open) {
            if showsTitle {
                Label("Verified", systemImage: "checkmark.seal.fill").foregroundStyle(.blue)
            } else {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
            }
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel("Verified")
        .accessibilityHint(help)
        .quickLookPreview($previewURL)
    }

    private var help: String {
        switch proof {
        case .link(let url): String(localized: "Verified. Opens \(url.host() ?? url.absoluteString)")
        case .document(let document): String(localized: "Verified. Opens \(document.displayTitle)")
        }
    }

    private func open() {
        switch proof {
        case .link(let url): openURL(url)
        case .document(let document): previewURL = document.fileURL()
        }
    }
}

/// A proof or credential link field, with the seal once the record has proof.
struct ProofField<Model: DocumentOwner>: View {
    let editor: RecordEditor<Model>
    let title: LocalizedStringKey
    let link: ReferenceWritableKeyPath<Model, String>

    var body: some View {
        // Label above a full-width field, so long links don't crowd the label; the seal is centered beside both.
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                TextField(title, text: editor.binding(link), prompt: Text("https://"))
                    .labelsHidden()
            }
            if let proof = editor.record.proof { ProofSeal(proof: proof, showsTitle: true) }
        }
        FieldError(editor.error(for: link))
    }
}

#Preview {
    Form {
        HStack {
            Text("iOS Engineer")
            ProofSeal(proof: .link(URL(string: "https://example.com")!))
        }
        ProofSeal(proof: .link(URL(string: "https://example.com")!), showsTitle: true)
    }
    .formStyle(.grouped)
    .frame(width: 400, height: 200)
}
