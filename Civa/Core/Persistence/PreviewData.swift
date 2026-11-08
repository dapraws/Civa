//
//  PreviewData.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

#if DEBUG
import SwiftData
import SwiftUI

extension ModelContainer {
    /// In-memory store with the sample person, for SwiftUI previews and debug runs. Fresh on every launch.
    static let preview: ModelContainer = {
        let container = try! ModelContainer.civa(inMemory: true)
        SampleProfile.populate(container.mainContext)
        return container
    }()
}

/// Which data a debug build runs on. Debug builds start on fresh sample data every launch, so
/// testing never touches real data. Settings → Developer switches mode after a restart.
nonisolated enum DataMode: String, CaseIterable {
    /// The fictional sample person, fresh every launch.
    case sample
    /// Nothing at all, fresh every launch, with the welcome, checklist, and tips shown again:
    /// Civa as a new user first sees it.
    case empty
    /// The real store.
    case real

    static let key = "CivaDataMode"
    /// The old on/off switch, read until a mode is picked.
    private static let realDataKey = "CivaUseRealData"

    static let current: DataMode = {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "CivaSampleData") { return .sample }
        if let mode = defaults.string(forKey: key).flatMap(DataMode.init) { return mode }
        return defaults.bool(forKey: realDataKey) ? .real : .sample
    }()

    var title: String {
        switch self {
        case .sample: String(localized: "Sample Data")
        case .empty: String(localized: "Empty, Like a New User")
        case .real: String(localized: "My Real Data")
        }
    }
}

/// Sample files for manual checks.
enum PreviewSamples {
    static let cvText = """
    Rina Wijaya
    Product Designer
    Bandung | rina@example.com | +62 811 2222 3333 | linkedin.com/in/rinawijaya

    PROFILE
    Product designer focused on fintech apps.

    PENGALAMAN KERJA
    Senior Product Designer — Tokopedia
    Jan 2023 – Present
    • Led the checkout redesign, lifting conversion by 9%
    • Built the design system used by 40 designers
    Product Designer at Gojek
    Agustus 2020 - Desember 2022
    - Designed GoPay onboarding

    PENDIDIKAN
    Institut Teknologi Bandung
    S1 Desain Komunikasi Visual, 2016 – 2020

    Certifications
    Google UX Design Certificate (2021)

    Skills
    Design: Figma, Sketch, Prototyping
    Research, Usability Testing

    Hobbies
    Hiking
    """

    /// A small LinkedIn data export, unzipped, in the app's temporary folder.
    static func writeSampleLinkedInExport() -> URL? {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Basic_LinkedInDataExport_Sample")
        let files = [
            "Profile.csv": "First Name,Last Name,Headline,Geo Location,Websites\nRina,Wijaya,Product Designer,\"Bandung, Indonesia\",[PORTFOLIO:https://rina.design]\n",
            "Email Addresses.csv": "Email Address,Confirmed,Primary,Updated On\nrina@example.com,Yes,Yes,1/1/24\n",
            "Positions.csv": "Company Name,Title,Description,Location,Started On,Finished On\nTokopedia,Senior Product Designer,\"Led the checkout redesign\nBuilt the design system\",Jakarta,Jan 2023,\nGojek,Product Designer,Designed GoPay onboarding,Jakarta,Aug 2020,Dec 2022\n",
            "Education.csv": "School Name,Start Date,End Date,Notes,Degree Name,Activities\nInstitut Teknologi Bandung,2016,2020,,S1 Desain Komunikasi Visual,\n",
            "Skills.csv": "Name\nFigma\nPrototyping\nUsability Testing\nSwift\n",
        ]
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (name, text) in files { try text.write(to: folder.appending(path: name), atomically: true, encoding: .utf8) }
            return folder
        } catch {
            return nil
        }
    }

    /// A Word copy of `cvText` in the app's temporary folder, which the sandbox can read.
    static func writeSampleCV() -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: "Sample CV.docx")
        let text = NSAttributedString(string: cvText)
        guard let data = try? text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        ), (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}

extension RecordEditor {
    /// Editor on a sample record of this type.
    static func preview(needsReview: Bool = false) -> RecordEditor<Model> {
        let context = ModelContainer.preview.mainContext
        let records = try! context.fetch(FetchDescriptor<Model>())
        let record = records.first { $0.needsReview == needsReview } ?? records[0]
        return RecordEditor(record: record, context: context)
    }
}

extension View {
    /// The environment every Civa view expects, backed by sample data.
    func previewEnvironment() -> some View {
        modelContainer(.preview)
            .environment(UnsavedChangesGuard())
            .environment(AppNavigation())
    }
}
#endif
