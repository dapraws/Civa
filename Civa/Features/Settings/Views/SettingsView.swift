//
//  SettingsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Privacy and integration settings (NFR-002).
struct SettingsView: View {
    @AppStorage(Brandfetch.fetchesLogosKey) private var fetchesLogos = true
    #if DEBUG
    @AppStorage(DataMode.realDataKey) private var usesRealData = false
    #endif

    var body: some View {
        Form {
            ClaudeSettingsSection()
            Section {
                Toggle("Fetch Logos Online", isOn: $fetchesLogos)
                    .disabled(Brandfetch.clientID == nil)
            } header: {
                Text("Logos")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("When you type a company or school name, Civa looks up matching brands on Brandfetch and shows their logos. Only the names you type are sent. Everything else stays on this Mac, and logos never appear on your resume.")
                    if Brandfetch.clientID == nil {
                        Text("Logo lookup isn't set up in this build.")
                    }
                }
            }
            #if DEBUG
            Section {
                Toggle("Use My Real Data", isOn: $usesRealData)
            } header: {
                Text("Developer")
            } footer: {
                Text("Debug builds start with fresh sample data every launch, so testing never touches your real data. Turn this on to use your real data instead. Takes effect after you restart Civa.")
            }
            #endif
        }
        .formStyle(.grouped)
        .frame(maxWidth: 640)
    }
}

#Preview {
    SettingsView()
        .frame(width: 700, height: 400)
}
