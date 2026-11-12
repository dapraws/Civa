//
//  Typography.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import CoreText
import SwiftUI

/// Young Serif (SIL OFL 1.1, `Resources/Fonts/OFL.txt`) is registered at launch because the
/// project's Info.plist is generated, so `ATSApplicationFontsPath` isn't available.
enum CivaFonts {
    static let youngSerif = "YoungSerif-Regular"

    static func register() {
        guard let url = Bundle.main.url(forResource: youngSerif, withExtension: "ttf")
            ?? Bundle.main.url(forResource: youngSerif, withExtension: "ttf", subdirectory: "Fonts")
        else { return }
        // Fails harmlessly when already registered (tests, previews).
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

/// DESIGN.md §4.2. Young Serif only for titles, the wordmark and Dashboard counts; never below 17 pt.
extension Font {
    static let pageTitle = Font.custom(CivaFonts.youngSerif, size: 26, relativeTo: .title)
    static let detailTitle = Font.custom(CivaFonts.youngSerif, size: 20, relativeTo: .title2)
    static let sectionTitle = Font.custom(CivaFonts.youngSerif, size: 17, relativeTo: .title3)
    static let wordmark = Font.custom(CivaFonts.youngSerif, size: 20, relativeTo: .title2)
    static let statNumber = Font.custom(CivaFonts.youngSerif, size: 22, relativeTo: .title2)
    static let bodyEmphasis = Font.body.weight(.semibold)
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text("Career Profile").font(.pageTitle)
        Text("iOS Engineer · Gojek").font(.detailTitle)
        Text("Contact").font(.sectionTitle)
        Text("Civa").font(.wordmark)
        Text("5 of 6").font(.statNumber)
        Text("Row title").font(.bodyEmphasis)
        Text("Body text in SF Pro.").font(.body)
        Text("Helper text").font(.callout)
        Text("Edited 2 hours ago").font(.caption)
    }
    .padding()
    .onAppear(perform: CivaFonts.register)
}

#Preview("Dark") {
    Text("Career Profile").font(.pageTitle).padding()
        .onAppear(perform: CivaFonts.register)
        .preferredColorScheme(.dark)
}
