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

    var body: some View {
        Form {
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
        }
        .formStyle(.grouped)
        .frame(maxWidth: 640)
    }
}

#Preview {
    SettingsView()
        .frame(width: 700, height: 400)
}
