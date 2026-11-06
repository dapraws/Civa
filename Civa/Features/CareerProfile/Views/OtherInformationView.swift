//
//  OtherInformationView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Other Information holds three record types, each with its own list.
struct OtherInformationView: View {
    enum Kind: CaseIterable, Identifiable {
        case achievements, certifications, skills

        var id: Self { self }

        var title: String {
            switch self {
            case .achievements: String(localized: "Achievements")
            case .certifications: String(localized: "Certifications")
            case .skills: String(localized: "Skills")
            }
        }
    }

    @Environment(UnsavedChangesGuard.self) private var changes
    @State private var kind: Kind = .achievements
    /// The type clicked while the unsaved-changes prompt is up.
    @State private var pendingKind: Kind?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: changes.selection($kind, pending: $pendingKind)) {
                ForEach(Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(10)

            Divider()

            Group {
                switch kind {
                case .achievements: AchievementList()
                case .certifications: CertificationList()
                case .skills: SkillList()
                }
            }
            .id(kind)
        }
    }
}

#Preview {
    NavigationStack {
        OtherInformationView()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}
