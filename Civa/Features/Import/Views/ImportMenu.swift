//
//  ImportMenu.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// "Import": a CV (FR-020) or LinkedIn's data export (FR-021), then review what was found.
struct ImportMenu: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var choosing: ImportRequest.Kind?
    @State private var request: ImportRequest?

    var body: some View {
        Menu {
            Button("CV (PDF or Word)…", systemImage: "doc.text") { choose(.cv) }
            Button("LinkedIn Data Export…", systemImage: "archivebox") { choose(.linkedInExport) }
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
        .labelStyle(.iconOnly)
        .menuIndicator(.hidden)
        .help("Add your details from a CV or a LinkedIn data export")
        .fileImporter(
            isPresented: Binding(get: { choosing != nil }, set: { if !$0 { choosing = nil } }),
            allowedContentTypes: choosing == .linkedInExport ? [.zip, .folder] : CVTextExtractor.contentTypes
        ) { result in
            if case .success(let url) = result, let kind = choosing { request = ImportRequest(url: url, kind: kind) }
            choosing = nil
        }
        .sheet(item: $request) { ImportReviewSheet(request: $0) }
        #if DEBUG
        // Manual checks: -CivaImportSample YES opens the review on a sample Word CV.
        .onAppear {
            if UserDefaults.standard.bool(forKey: "CivaImportSample"), let url = PreviewSamples.writeSampleCV() {
                request = ImportRequest(url: url, kind: .cv)
            }
            // -CivaImportLinkedInSample YES opens it on a sample LinkedIn export.
            if UserDefaults.standard.bool(forKey: "CivaImportLinkedInSample"), let url = PreviewSamples.writeSampleLinkedInExport() {
                request = ImportRequest(url: url, kind: .linkedInExport)
            }
        }
        #endif
    }

    private func choose(_ kind: ImportRequest.Kind) {
        changes.perform { choosing = kind }
    }
}

#Preview {
    ImportMenu()
        .padding()
        .previewEnvironment()
}
