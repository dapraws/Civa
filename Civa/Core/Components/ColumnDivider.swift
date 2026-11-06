//
//  ColumnDivider.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// A divider you drag to resize the column next to it. Used instead of HSplitView, which sizes
/// panes from their ideal widths and pushed the resume editor past the window edge.
struct ColumnDivider: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    /// 1 when the resized column is left of the divider, -1 when it's on the right.
    let direction: CGFloat

    @State private var startWidth: CGFloat?

    var body: some View {
        Divider()
            .overlay {
                // A wider grab area than the 1 pt line, without taking layout space.
                Color.clear
                    .frame(width: 9)
                    .contentShape(.rect)
                    .pointerStyle(.columnResize)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let start = startWidth ?? width
                                startWidth = start
                                width = min(max(start + direction * value.translation.width, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in startWidth = nil }
                    )
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var width: CGFloat = 200
    HStack(spacing: 0) {
        Color.blue.opacity(0.2).frame(width: width)
        ColumnDivider(width: $width, range: 120...400, direction: 1)
        Color.clear
    }
    .frame(width: 600, height: 200)
}
