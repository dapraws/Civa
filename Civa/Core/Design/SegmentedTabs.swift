//
//  SegmentedTabs.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Page tabs under a title (DESIGN.md §7.4), such as Career Profile's and AI Activity's.
/// Arrow keys move between tabs while the control has keyboard focus.
struct SegmentedTabs<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    var count: (Tab) -> Int? = { _ in nil }

    @FocusState private var isFocused: Bool

    init(_ tabs: [Tab], selection: Binding<Tab>, title: @escaping (Tab) -> String, count: @escaping (Tab) -> Int? = { _ in nil }) {
        self.tabs = tabs
        _selection = selection
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Segment(title: title(tab), count: count(tab), isSelected: tab == selection) {
                    withAnimation(Motion.standard) { selection = tab }
                }
            }
        }
        .padding(2)
        .background(Color.sidebar, in: .rect(cornerRadius: Radius.control))
        .overlay { RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Color.hairline) }
        .fixedSize()
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isFocused)
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .accessibilityElement(children: .contain)
    }

    private func move(_ step: Int) -> KeyPress.Result {
        guard let index = tabs.firstIndex(of: selection) else { return .ignored }
        let next = index + step
        guard tabs.indices.contains(next) else { return .handled }
        withAnimation(Motion.standard) { selection = tabs[next] }
        return .handled
    }
}

private struct Segment: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Text(title)
                if let count {
                    Text(count, format: .number).monospacedDigit().foregroundStyle(Color.textSecondary)
                }
            }
            .font(isSelected ? .bodyEmphasis : .body)
            .foregroundStyle(isSelected || isHovered ? Color.textPrimary : Color.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.surface)
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TabsPreview: View {
    enum Tab: String, CaseIterable, Identifiable {
        case personal = "Personal", professional = "Professional", education = "Education", projects = "Projects"
        var id: Self { self }
    }

    @State private var tab = Tab.professional

    var body: some View {
        SegmentedTabs(Tab.allCases, selection: $tab, title: \.rawValue) { $0 == .projects ? 3 : nil }
            .padding()
            .background(Color.canvas)
    }
}

#Preview { TabsPreview() }

#Preview("Dark") { TabsPreview().preferredColorScheme(.dark) }
