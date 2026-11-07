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
    /// Icon only in toolbars; with its title on the Dashboard.
    var showsTitle = false
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var isChoosing = false
    /// Kept apart from `isChoosing`: the panel closes, clearing that, before the chosen file arrives.
    @State private var kind = ImportRequest.Kind.cv
    @State private var request: ImportRequest?

    var body: some View {
        Menu {
            Button("CV or LinkedIn PDF…", systemImage: "doc.text") { choose(.cv) }
            Button("LinkedIn Data Export…", systemImage: "archivebox") { choose(.linkedInExport) }
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
        .labelStyle(TitleOrIconLabelStyle(showsTitle: showsTitle))
        .menuIndicator(showsTitle ? .visible : .hidden)
        .help("Add your details from a CV, a LinkedIn PDF, or a LinkedIn data export")
        .fileImporter(
            isPresented: $isChoosing,
            allowedContentTypes: kind == .linkedInExport ? [.zip, .folder] : CVTextExtractor.contentTypes
        ) { result in
            if case .success(let url) = result { request = ImportRequest(url: url, kind: kind) }
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
        changes.perform {
            self.kind = kind
            isChoosing = true
        }
    }
}

private struct TitleOrIconLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        if showsTitle {
            Label(configuration)
        } else {
            configuration.icon
        }
    }
}

#Preview {
    ImportMenu()
        .padding()
        .previewEnvironment()
}
