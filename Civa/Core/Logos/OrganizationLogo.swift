//
//  OrganizationLogo.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftData
import SwiftUI

/// A company or school logo, or its initials when there's no logo, no connection, or lookups are off.
/// Shown in Civa only; logos never go on a resume.
struct OrganizationLogo: View {
    let name: String
    var size: CGFloat = 32

    @Query private var matches: [Organization]
    @AppStorage(Brandfetch.fetchesLogosKey) private var fetchesLogos = true

    init(name: String, size: CGFloat = 32) {
        self.name = name
        self.size = size
        let key = Organization.key(for: name)
        _matches = Query(filter: #Predicate { $0.key == key })
    }

    var body: some View {
        Group {
            if fetchesLogos, let domain = matches.first?.domain, let url = Brandfetch.logoURL(domain: domain) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
    }

    private var initials: some View {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return ZStack {
            Rectangle().fill(Self.color(for: name).gradient)
            if letters.isEmpty {
                Image(systemName: "building.2").font(.system(size: size * 0.45))
            } else {
                Text(letters).font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
    }

    /// Stable across launches, unlike `hashValue`.
    private static func color(for name: String) -> Color {
        let colors: [Color] = [.blue, .teal, .indigo, .orange, .pink, .purple, .green, .brown]
        let sum = Organization.key(for: name).unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[sum % colors.count]
    }
}

#Preview {
    HStack(spacing: 12) {
        OrganizationLogo(name: "Apple", size: 48)
        OrganizationLogo(name: "Northwind Traders", size: 48)
        OrganizationLogo(name: "", size: 48)
    }
    .padding()
    .previewEnvironment()
}
