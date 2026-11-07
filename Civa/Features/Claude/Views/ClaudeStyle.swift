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
