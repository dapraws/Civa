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
    @AppStorage(DataMode.key) private var dataMode = DataMode.current
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
                Picker("Data", selection: $dataMode) {
                    ForEach(DataMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Sample and Empty start fresh every launch, so testing never touches your real data. Empty also shows the welcome, Getting Started, and tips again. Takes effect after you restart Civa.")
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
