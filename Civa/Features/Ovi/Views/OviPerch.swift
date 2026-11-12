//
//  OviPerch.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Ovi at the bottom of the sidebar (DESIGN.md §9.1). A button: with a "!" it opens the tip,
/// otherwise it opens Help. The bubble grows upward from here.
struct OviPerch: View {
    /// Applies a tip's action to the app (the resume being edited, the Tailor sheet).
    var perform: (OviAction) -> Void = { _ in }
    var openWhy: (OviTipID) -> Void = { _ in }

    @Environment(OviEngine.self) private var ovi
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    static let height: CGFloat = 72

    var body: some View {
        if ovi.state != .hidden {
            VStack(alignment: .leading, spacing: Space.s) {
                if case .waving(let match) = ovi.state {
                    OviBubble(
                        match: match,
                        act: { action in
                            perform(action)
                            ovi.took(action)
                        },
                        close: ovi.close,
                        why: { openWhy(match.tip) },
                        dontShowAgain: ovi.dontShowAgain,
                        turnOff: ovi.turnOff
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                }
                HStack(alignment: .bottom, spacing: Space.s) {
                    owl
                    if case .waving = ovi.state {
                        Text("Ovi")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .animation(reduceMotion ? nil : Motion.emphasis, value: ovi.state)
            .onChange(of: ovi.current?.tip) { old, new in
                if old == nil, new != nil, case .noticing = ovi.state {
                    AccessibilityNotification.Announcement("Ovi has a tip").post()
                }
            }
        }
    }

    private var owl: some View {
        Button {
            if case .noticing = ovi.state { ovi.open() } else { openWindow(id: "help") }
        } label: {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(height: Self.height)
                .overlay {
                    switch ovi.state {
                    case .noticing(let match): OviNoticeMark().id(match.tip)
                    case .waving(let match): OviTalkMarks().id(match.tip)
                    default: EmptyView()
                    }
                }
                .modifier(Tilt(isWaving: isWaving, reduceMotion: reduceMotion))
                .contentTransition(.opacity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .civaFocusRing(RoundedRectangle(cornerRadius: Radius.control), isFocused: isFocused)
        .pointerStyle(.link)
        .accessibilityLabel(Text(isNoticing ? "Ovi has a tip" : "Ovi, Civa's guide"))
        .accessibilityHint(Text(isNoticing ? "Opens the tip" : "Opens Help"))
        .help(isNoticing ? "Ovi has a tip" : "Ovi, Civa's guide")
    }

    private var isNoticing: Bool {
        if case .noticing = ovi.state { true } else { false }
    }

    private var isWaving: Bool {
        if case .waving = ovi.state { true } else { false }
    }

    private var imageName: String {
        switch ovi.state {
        case .noticing: "Ovi/Noticing"
        case .waving: "Ovi/Waving"
        case .happy: "Ovi/Happy"
        default: "Ovi/Front"
        }
    }
}

/// Two small tilts around the feet when the bubble opens (DESIGN.md §10). None with Reduce Motion.
private struct Tilt: ViewModifier {
    let isWaving: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: isWaving) { view, angle in
            view.rotationEffect(.degrees(reduceMotion || !isWaving ? 0 : angle), anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-3, duration: 0.125)
                CubicKeyframe(3, duration: 0.25)
                CubicKeyframe(0, duration: 0.125)
                CubicKeyframe(-3, duration: 0.125)
                CubicKeyframe(3, duration: 0.25)
                CubicKeyframe(0, duration: 0.125)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        Spacer()
        OviPerch()
    }
    .padding(12)
    .frame(width: 204, height: 420, alignment: .bottomLeading)
    .background(Color.sidebar)
    .environment(OviEngine())
}
