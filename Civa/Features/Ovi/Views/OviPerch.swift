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
    /// Ovi hopping off or onto the perch after Show Ovi changes (DESIGN.md §10).
    @State private var hop: OviHop?
    /// Restarts the hop when Show Ovi flips again mid-hop.
    @State private var hopCount = 0

    static let height: CGFloat = 160

    var body: some View {
        Group {
            if let hop {
                OviHopper(hop: hop, height: Self.height)
                    .id(hopCount)
            } else if ovi.state != .hidden {
                perch
            }
        }
        .onChange(of: ovi.state == .hidden) { _, isHidden in
            // Reduce Motion: no hop, Ovi just appears or disappears.
            guard !reduceMotion else { return }
            hopCount += 1
            let count = hopCount
            hop = isHidden ? .leaving : .arriving
            Task {
                try? await Task.sleep(for: .seconds(OviHop.duration))
                if hopCount == count { hop = nil }
            }
        }
    }

    private var perch: some View {
            VStack(alignment: .leading, spacing: Space.s) {
                if case .waving(let match) = ovi.state {
                    OviBubble(
                        match: match,
                        act: { action in
                            perform(action)
                            if case .tailorCopy = action { ovi.handedOff() } else { ovi.took(action) }
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
            // Esc closes the bubble wherever focus is in the sidebar, even after a mouse click on Ovi.
            .onExitCommand {
                if case .waving = ovi.state { ovi.close() }
            }
            .onChange(of: ovi.current?.tip) { old, new in
                if old == nil, new != nil, case .noticing = ovi.state {
                    AccessibilityNotification.Announcement("Ovi has a tip").post()
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
                .background(alignment: .bottom) { OviShadow(height: Self.height) }
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

/// A soft contact shadow under Ovi's feet, drawn in code so it scales with him (DESIGN.md §9.1).
/// `lift` is how high he is (0 on the ground, 1 at the top of a hop): the shadow shrinks and fades.
struct OviShadow: View {
    let height: CGFloat
    /// Where the feet sit across the image, as a fraction of its width (front pose: centered).
    var feetX: CGFloat = 0.5
    var lift: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let width = height * OviShadow.aspect
        let size = CGSize(width: height * 0.46 * (1 - 0.35 * lift), height: height * 0.07 * (1 - 0.35 * lift))
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.black.opacity(colorScheme == .dark ? 0.55 : 0.22), .black.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size.width / 2
                )
            )
            .frame(width: size.width, height: size.height)
            .opacity(1 - 0.5 * lift)
            // The feet stand 4% above the image's bottom edge (the images are 524 × 611, feet at 587).
            .offset(x: (feetX - 0.5) * width, y: size.height / 2 - height * 0.039)
            .frame(width: width)
            .accessibilityHidden(true)
    }

    /// Width over height of Ovi's images.
    static let aspect: CGFloat = 524 / 611
}

/// Hopping off the perch (left, out of the window) or back onto it, in the side pose.
nonisolated enum OviHop: Equatable {
    case leaving, arriving

    static let hopTime = 0.34
    static let duration = 3 * hopTime + 0.1
}

/// Ovi in the side pose hopping three times: off to the left edge, or in from it.
/// Arriving he faces right (the image's own way); leaving he's mirrored to face left.
private struct OviHopper: View {
    let hop: OviHop
    let height: CGFloat

    /// Flips on appear to start the keyframes (`repeating: false` would hold the first frame).
    @State private var isHopping = false

    private struct Frame {
        var x: CGFloat
        var lift: CGFloat
    }

    /// Far enough left that all of Ovi is past the window's edge.
    private var away: CGFloat { -(height * OviShadow.aspect + 40) }

    var body: some View {
        let start = Frame(x: hop == .leaving ? 0 : away, lift: 0)
        let end: CGFloat = hop == .leaving ? away : 0
        // In the side image the body sits left of center (x 66–366 of 524); mirrored, right of it.
        let feetX: CGFloat = hop == .leaving ? 0.59 : 0.41
        ZStack(alignment: .bottom) {
            Color.clear.frame(width: height * OviShadow.aspect, height: height)
        }
        .keyframeAnimator(initialValue: start, trigger: isHopping) { content, frame in
            content
                .overlay(alignment: .bottom) {
                    OviShadow(height: height, feetX: feetX, lift: frame.lift)
                        .offset(x: frame.x)
                }
                .overlay {
                    Image("Ovi/Side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .scaleEffect(x: hop == .leaving ? -1 : 1)
                        // A little squash on landing reads as weight.
                        .scaleEffect(x: 1, y: 1 - 0.06 * max(0, 0.25 - frame.lift) * 4, anchor: .bottom)
                        .offset(x: frame.x, y: -frame.lift * height * 0.2)
                }
        } keyframes: { _ in
            // Three hops; the builders don't take loops.
            let t = OviHop.hopTime
            let step = (end - start.x) / 3
            KeyframeTrack(\.x) {
                CubicKeyframe(start.x + step, duration: t)
                CubicKeyframe(start.x + step * 2, duration: t)
                CubicKeyframe(end, duration: t)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(1, duration: t * 0.45)
                CubicKeyframe(0, duration: t * 0.55)
                CubicKeyframe(1, duration: t * 0.45)
                CubicKeyframe(0, duration: t * 0.55)
                CubicKeyframe(1, duration: t * 0.45)
                CubicKeyframe(0, duration: t * 0.55)
            }
        }
        .onAppear { isHopping = true }
        .accessibilityHidden(true)
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
