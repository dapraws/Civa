//
//  ClaudeStyle.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Orange marks Claude, and only Claude, so its features and its writing stand out.
extension Color {
    nonisolated static let claude = Color(.sRGB, red: 0.85, green: 0.47, blue: 0.34)
}

extension ShapeStyle where Self == Color {
    nonisolated static var claude: Color { .claude }
}

/// "Claude" in a small orange capsule: on text Claude wrote, until you edit it.
struct ClaudeTag: View {
    var title: LocalizedStringKey = "Claude"

    var body: some View {
        Label(title, systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(.claude)
            .background(.claude.opacity(0.14), in: .capsule)
            .help("Written by Claude. The tag goes away when you edit it.")
    }
}

/// An orange count of things from Claude waiting for you.
struct ClaudeCount: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(.claude, in: .capsule)
            .help("^[\(count) suggestion](inflect: true) from Claude to review")
    }
}

/// How a request reaches Claude and comes back, in three plain steps. Claude can't be started
/// from Civa, so step 2 is the one people miss.
struct ClaudeHowItWorks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Ask in Civa", "Press an orange Claude button. Civa saves the request.")
            step(2, "Tell Claude Desktop", "Send “\(ClaudeAsk.prompt)” Claude reads only what you allowed.")
            step(3, "Review in Civa", "Claude's suggestions come back here. Nothing changes until you apply one.")
        }
    }

    private func step(_ number: Int, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number, format: .number)
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.claude, in: .circle)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("How It Works") {
    ClaudeHowItWorks().padding().frame(width: 420)
}

#Preview {
    VStack(spacing: 12) {
        ClaudeTag()
        ClaudeCount(count: 3)
        Button("Improve with Claude", systemImage: "sparkles") {}
            .buttonStyle(.bordered)
            .tint(.claude)
    }
    .padding()
}
