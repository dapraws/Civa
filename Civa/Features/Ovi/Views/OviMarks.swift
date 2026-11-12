//
//  OviMarks.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import SwiftUI

/// Positions are on a 96 × 112 grid over Ovi's image (DESIGN.md §9.3), so the marks scale with Ovi.
nonisolated private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + x / 96 * rect.width, y: rect.minY + y / 112 * rect.height)
}

/// The stroke of the cobalt "!" beside Ovi's head: Ovi noticed something.
nonisolated private struct NoticeStroke: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: point(77, 1, in: rect))
            path.addLine(to: point(77, 11, in: rect))
        }
    }
}

nonisolated private struct NoticeDot: Shape {
    func path(in rect: CGRect) -> Path {
        let center = point(77, 15, in: rect)
        // At least as wide as the 2 pt stroke, so the dot still reads at the 72 pt perch.
        let radius = max(1.4 / 96 * rect.width, 1.4)
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// One of the three feather-brown ticks beside Ovi's head: Ovi is talking.
nonisolated private struct Tick: Shape {
    let from: (CGFloat, CGFloat)
    let to: (CGFloat, CGFloat)

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: point(from.0, from.1, in: rect))
            path.addLine(to: point(to.0, to.1, in: rect))
        }
    }
}

/// The "!" (Noticing): draws in, pulses three times, then holds still. Reduce Motion: fully drawn.
struct OviNoticeMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        ZStack {
            NoticeStroke()
                .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                .stroke(Color.accentText, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            NoticeDot()
                .fill(Color.accentText)
                .opacity(drawn || reduceMotion ? 1 : 0)
        }
        .keyframeAnimator(initialValue: 1.0, trigger: drawn) { content, opacity in
            content.opacity(reduceMotion ? 1 : opacity)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(1, duration: 0.3)
                CubicKeyframe(0.4, duration: 0.8)
                CubicKeyframe(1, duration: 0.8)
                CubicKeyframe(0.4, duration: 0.8)
                CubicKeyframe(1, duration: 0.8)
                CubicKeyframe(0.4, duration: 0.8)
                CubicKeyframe(1, duration: 0.8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { drawn = true }
        }
        .accessibilityHidden(true)
    }
}

/// The ticks (Waving): draw in one after another, then fade at 2.2 s. Reduce Motion: drawn at once,
/// still fading at 2.2 s.
struct OviTalkMarks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var faded = false

    private static let ticks: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [
        ((67, 9), (72, 2)), ((70, 15), (78, 11)), ((71, 21), (80, 21)),
    ]

    var body: some View {
        ZStack {
            ForEach(Self.ticks.indices, id: \.self) { index in
                Tick(from: Self.ticks[index].0, to: Self.ticks[index].1)
                    .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                    .stroke(Color.oviTalk, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18).delay(Double(index) * 0.05), value: drawn)
            }
        }
        .opacity(faded ? 0 : 1)
        .onAppear {
            drawn = true
            withAnimation(.easeIn(duration: 0.3).delay(2.2)) { faded = true }
        }
        .accessibilityHidden(true)
    }
}

private struct MarksPreview: View {
    var body: some View {
        HStack(spacing: 24) {
            Image("Ovi/Noticing").resizable().scaledToFit().frame(height: 144).overlay { OviNoticeMark() }
            Image("Ovi/Waving").resizable().scaledToFit().frame(height: 144).overlay { OviTalkMarks() }
        }
        .padding()
        .background(Color.sidebar)
    }
}

#Preview { MarksPreview() }

#Preview("Dark") { MarksPreview().preferredColorScheme(.dark) }
