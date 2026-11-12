//
//  PageHeader.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// A page's main action (such as "Add Experience"), handed up from a record list or gallery to
/// the page's title row, which shows it as the Primary button.
struct PageAction: Equatable {
    let id: String
    let title: String
    let systemImage: String?
    let shortcut: KeyEquivalent?
    let run: @MainActor () -> Void

    init(id: String, title: String, systemImage: String?, shortcut: KeyEquivalent?, run: @escaping @MainActor () -> Void) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.run = run
    }

    static func == (lhs: PageAction, rhs: PageAction) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }
}

struct PageActionKey: PreferenceKey {
    static let defaultValue: PageAction? = nil

    static func reduce(value: inout PageAction?, nextValue: () -> PageAction?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Offers `action` to the page's title row (`PageHeader`'s `primary`).
    func pageAction(_ action: PageAction?) -> some View {
        preference(key: PageActionKey.self, value: action)
    }
}

/// The title row at the top of a page (DESIGN.md §2, §5.2): serif title on the leading edge,
/// the page's actions trailing. An opened record adds Back before its name.
struct PageHeader<Actions: View>: View {
    let title: String
    var back: (() -> Void)?
    var titleFont: Font = .pageTitle
    @ViewBuilder let actions: Actions

    /// `actions` has no default on purpose: with one, a trailing `{ … }` would bind to `back`.
    init(_ title: String, back: (() -> Void)? = nil, titleFont: Font = .pageTitle, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.back = back
        self.titleFont = titleFont
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: Space.s) {
            if let back {
                Button("Back", systemImage: "chevron.left", action: back)
                    .labelStyle(.iconOnly)
                    .civaButton(.textLink)
                    .frame(width: Size.minTarget, height: Size.minTarget)
                    .keyboardShortcut("[", modifiers: .command)
                    .help("Back (⌘[)")
            }
            Text(title)
                .font(titleFont)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.l)
            actions
        }
    }
}

extension PageHeader where Actions == EmptyView {
    init(_ title: String, back: (() -> Void)? = nil, titleFont: Font = .pageTitle) {
        self.init(title, back: back, titleFont: titleFont) { EmptyView() }
    }
}

/// The Primary button for a `PageAction`, with its keyboard shortcut.
struct PageActionButton: View {
    let action: PageAction?

    var body: some View {
        if let action {
            Group {
                if let systemImage = action.systemImage {
                    Button(action.title, systemImage: systemImage, action: action.run)
                } else {
                    Button(action.title, action: action.run)
                }
            }
            .civaButton(.primary)
            .modifier(OptionalShortcut(key: action.shortcut))
            .help(action.shortcut.map { "\(action.title) (⌘\(String($0.character).uppercased()))" } ?? action.title)
        }
    }
}

private struct OptionalShortcut: ViewModifier {
    let key: KeyEquivalent?

    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key) } else { content }
    }
}

/// A page's frame (DESIGN.md §5.2): 24 pt sides, 20 pt top, 32 pt bottom, left-anchored with an
/// optional max width, on `canvas`.
struct PageFrame<Content: View>: View {
    let maxWidth: CGFloat?
    @ViewBuilder let content: Content

    init(maxWidth: CGFloat?, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            .padding(.top, 20)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.canvas)
    }
}

private struct HeaderPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            PageHeader("Career Profile") {
                Button("Import…") {}.civaButton(.secondary)
                PageActionButton(action: PageAction(id: "a", title: "Add Experience", systemImage: "plus", shortcut: "n") {})
            }
            PageHeader("iOS Engineer · Gojek", back: {}, titleFont: .detailTitle)
        }
        .frame(width: 720)
        .padding()
        .background(Color.canvas)
    }
}

#Preview { HeaderPreview() }

#Preview("Dark") { HeaderPreview().preferredColorScheme(.dark) }
