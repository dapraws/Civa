//
//  SidebarPeek.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 15/11/26.
//

import SwiftUI

/// The sidebar of a narrow window: hidden behind the left edge, sliding in over the page while
/// the pointer is there. A clay dot on the edge says Ovi has a tip.
struct SidebarPeek<Sidebar: View>: View {
    @Binding var isShown: Bool
    let hasTip: Bool
    @ViewBuilder let sidebar: Sidebar

    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: 8)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .onHover { if $0 { show() } }
            if hasTip, !isShown {
                Circle()
                    .fill(Color.claude)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 3)
                    // Level with Ovi's perch at the foot of the sidebar.
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilityLabel(Text("Ovi has a tip"))
            }
            if isShown {
                sidebar
                    .frame(width: 220)
                    .frame(maxHeight: .infinity)
                    .background(Color.sidebar.ignoresSafeArea())
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.hairline).frame(width: 1).ignoresSafeArea()
                    }
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 4)
                    .onHover { inside in inside ? show() : scheduleHide() }
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.snappy(duration: 0.25), value: isShown)
        .animation(.easeOut, value: hasTip)
    }

    private func show() {
        hideTask?.cancel()
        isShown = true
    }

    /// A short delay, so brushing past the edge or opening a menu doesn't snap it shut.
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            isShown = false
        }
    }
}

#Preview {
    SidebarPeek(isShown: .constant(true), hasTip: false) { Text("Sidebar").padding() }
        .frame(width: 640, height: 400)
        .background(Color.canvas)
}

#Preview("Dark") {
    SidebarPeek(isShown: .constant(false), hasTip: true) { Text("Sidebar").padding() }
        .frame(width: 640, height: 400)
        .background(Color.canvas)
        .preferredColorScheme(.dark)
}
