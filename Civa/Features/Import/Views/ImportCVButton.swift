//
//  ImportCVButton.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// "Import CV…": choose a PDF or Word file, then review what was found (FR-020).
struct ImportCVButton: View {
    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var isChoosing = false
    @State private var file: URL?

    var body: some View {
        Button("Import CV…", systemImage: "doc.badge.plus") {
            changes.perform { isChoosing = true }
        }
        .help("Add your details from an existing CV (PDF or Word)")
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: CVTextExtractor.contentTypes) { result in
            if case .success(let url) = result { file = url }
        }
        .sheet(isPresented: Binding(get: { file != nil }, set: { if !$0 { file = nil } })) {
            if let file { ImportCVSheet(url: file) }
        }
        #if DEBUG
        // Manual checks: -CivaImportSample YES opens the review on a sample Word CV.
        .onAppear {
            if UserDefaults.standard.bool(forKey: "CivaImportSample") { file = PreviewSamples.writeSampleCV() }
        }
        #endif
    }
}

#Preview {
    ImportCVButton()
        .padding()
        .previewEnvironment()
}
