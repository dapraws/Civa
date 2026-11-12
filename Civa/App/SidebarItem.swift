//
//  SidebarItem.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// A sidebar row (DESIGN.md §7.7): soft fill, bold label, cobalt icon and a 3 pt cobalt bar when
/// selected. AI Activity's icon is always Claude orange, and its count is a Claude tint.
struct SidebarItem: View {
    let section: AppSection
    let isSelected: Bool
    var badge: Int?
    let select: () -> Void

    @State private var isHovered = false

    init(_ section: AppSection, isSelected: Bool, badge: Int? = nil, select: @escaping () -> Void) {
        self.section = section
        self.isSelected = isSelected
        self.badge = badge
        self.select = select
    }

    var body: some View {
        Button(action: select) {
            HStack(spacing: Space.s) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                Text(section.title)
                    .font(isSelected ? .bodyEmphasis : .body)
                    .foregroundStyle(isSelected || isHovered ? Color.textPrimary : Color.textSecondary)
                Spacer(minLength: 0)
                if let badge, badge > 0 {
                    Text(badge, format: .number)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.claudeText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.claudeTint, in: .rect(cornerRadius: Radius.tag))
                        .accessibilityLabel(Text("\(badge) waiting"))
                }
            }
            .padding(.horizontal, Space.s)
            .frame(height: Size.sidebarItem)
            .background(isSelected ? Color.selectionFill : isHovered ? Color.hover : .clear, in: .rect(cornerRadius: Radius.control))
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accent)
                        .frame(width: 3, height: 14)
                        .padding(.leading, 2)
                }
            }
            .contentShape(.rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .animation(Motion.standard, value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var iconColor: Color {
        if section == .aiActivity { return .claude }
        return isSelected ? .accent : .textSecondary
    }
}

private struct SidebarPreview: View {
    @State private var selection = AppSection.careerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(AppSection.allCases) { section in
                SidebarItem(section, isSelected: section == selection, badge: section == .aiActivity ? 3 : nil) {
                    selection = section
                }
            }
        }
        .padding(10)
        .frame(width: 204)
        .background(Color.sidebar)
    }
}

#Preview { SidebarPreview() }

#Preview("Dark") { SidebarPreview().preferredColorScheme(.dark) }
