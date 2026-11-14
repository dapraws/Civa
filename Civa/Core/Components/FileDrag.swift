//
//  FileDrag.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import SwiftUI

extension View {
    /// Drag a file out of Civa, such as into a job site's upload box, Mail, or Finder, instead of
    /// finding it in Finder. The file is written when the drag starts.
    func fileDrag(_ makeURL: @escaping () -> URL?) -> some View {
        onDrag {
            makeURL().flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        }
    }
}

/// A resume's PDF name when it leaves Civa: "Darrel Prawira - iOS Engineer.pdf", so a recruiter
/// sees whose it is and for what.
nonisolated enum ResumeFileName {
    static func make(fullName: String, target: String, title: String) -> String {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = if !name.isEmpty {
            "\(name) - \(target.isEmpty ? String(localized: "Resume") : target)"
        } else {
            title.isEmpty ? String(localized: "Resume") : title
        }
        return base.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
    }
}

extension Resume {
    /// This resume as a PDF in a temporary folder, for dragging out. Rewritten on every drag so it
    /// matches the latest edits.
    @MainActor func dragFile() -> URL? {
        let document = document
        let folder = FileManager.default.temporaryDirectory.appending(path: "Resumes/\(id.uuidString)")
        let url = folder.appending(path: ResumeFileName.make(fullName: document.header.fullName, target: targetPosition, title: title))
        do {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try ResumeRenderer.pdf(for: document).write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
