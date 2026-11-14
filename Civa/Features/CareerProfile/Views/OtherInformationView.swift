//
//  OtherInformationView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Other Information holds three record types, each with its own list.
struct OtherInformationView: View {
    enum Kind: String, CaseIterable, Identifiable {
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
    @Environment(AppNavigation.self) private var navigation
    @State private var kind: Kind = .achievements
    /// The type clicked while the unsaved-changes prompt is up.
    @State private var pendingKind: Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Its own band under the Career Profile tabs, with the same room above and below as theirs.
            SegmentedTabs(Kind.allCases, selection: changes.selection($kind, pending: $pendingKind), title: \.title)
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.m)
            Rectangle().fill(Color.hairline).frame(height: 1)

            Group {
                switch kind {
                case .achievements: AchievementList()
                case .certifications: CertificationList()
                case .skills: SkillList()
                }
            }
            .id(kind)
        }
        // Another page asked for a particular list, such as the Dashboard's Review link.
        .onAppear {
            if let raw = navigation.otherKind, let start = Kind(rawValue: raw) {
                kind = start
                navigation.otherKind = nil
            }
        }
        #if DEBUG
        // Manual checks: -CivaOtherKind skills opens Skills.
        .onAppear {
            if let raw = UserDefaults.standard.string(forKey: "CivaOtherKind"), let start = Kind(rawValue: raw) { kind = start }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        OtherInformationView()
    }
    .frame(width: 1000, height: 640)
    .previewEnvironment()
}
